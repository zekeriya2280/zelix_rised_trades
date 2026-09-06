-module(server@auth).
-compile([no_auto_import, nowarn_ignored, nowarn_unused_vars, nowarn_unused_function, nowarn_nomatch, inline]).
-export([decode_identity_response/1, verify_identity/1, verify_token/1, handle/2]).
-export_type([auth_result/0, firebase_user/0, credentials/0]).

-type auth_result() :: {auth_result, boolean(), binary(), binary(), binary()}.

-type firebase_user() :: {firebase_user, binary(), gleam@option:option(binary())}.

-type credentials() :: {credentials, binary(), binary(), gleam@option:option(binary())}.

-file("src\\server\\auth.gleam", 54).
-spec firebase_user_decoder() -> gleam@dynamic@decode:decoder(firebase_user()).
firebase_user_decoder() ->
    gleam@dynamic@decode:field(~"localId", {decoder, fun gleam@dynamic@decode:decode_string/1}, fun(Local_id) ->
        gleam@dynamic@decode:optional_field(~"displayName", none, gleam@dynamic@decode:optional({decoder, fun gleam@dynamic@decode:decode_string/1}), fun(Display_name) ->
            gleam@dynamic@decode:success({firebase_user, Local_id, Display_name})
        end)
    end).

-file("src\\server\\auth.gleam", 32).
-spec decode_identity_response(binary()) -> {ok, {binary(), binary()}} | {error, binary()}.
decode_identity_response(Text) ->
    Decoder = begin
        gleam@dynamic@decode:field(~"users", gleam@dynamic@decode:list(firebase_user_decoder()), fun(Users) ->
            gleam@dynamic@decode:success(Users)
        end)
    end,
    case gleam@json:parse(Text, Decoder) of
        {ok, [User | _]} ->
            Nickname = begin
                _pipe = erlang:element(3, User),
                _pipe@1 = gleam@option:unwrap(_pipe, ~""),
                gleam@string:trim(_pipe@1)
            end,
            case (string:length(Nickname) >= 3) andalso (string:length(Nickname) =< 24) of
                true ->
                    {ok, {erlang:element(2, User), Nickname}};

                false ->
                    {error, ~"Firebase account does not have a valid nickname."}
            end;

        {ok, []} ->
            {error, ~"Firebase token did not contain a user."};

        {error, _} ->
            {error, ~"Firebase token response was malformed."}
    end.

-file("src\\server\\auth.gleam", 317).
-spec firebase_error_message(integer(), binary()) -> binary().
firebase_error_message(Code, Body) ->
    case gleam@json:parse(Body, begin
        gleam@dynamic@decode:field(~"error", begin
            gleam@dynamic@decode:field(~"message", {decoder, fun gleam@dynamic@decode:decode_string/1}, fun(Inner) ->
                gleam@dynamic@decode:success(Inner)
            end)
        end, fun(Message) ->
            gleam@dynamic@decode:success(Message)
        end)
    end) of
        {ok, Message} ->
            <<<<<<"Firebase request failed ("/utf8, (erlang:integer_to_binary(Code))/binary>>/binary, "): "/utf8>>/binary, Message/binary>>;

        {error, _} ->
            <<<<"Firebase request failed ("/utf8, (erlang:integer_to_binary(Code))/binary>>/binary, ")."/utf8>>
    end.

-file("src\\server\\auth.gleam", 300).
-spec firebase_post(binary(), binary(), binary()) -> {ok, binary()} | {error, binary()}.
firebase_post(Api_key, Path, Body) ->
    Url = <<<<<<"https://identitytoolkit.googleapis.com/v1"/utf8, Path/binary>>/binary, "?key="/utf8>>/binary, Api_key/binary>>,
    case gleam@http@request:to(Url) of
        {ok, Req} ->
            Req@1 = begin
                _pipe = Req,
                _pipe@1 = gleam@http@request:set_method(_pipe, post),
                _pipe@2 = gleam@http@request:prepend_header(_pipe@1, ~"content-type", ~"application/json"),
                gleam@http@request:set_body(_pipe@2, Body)
            end,
            case gleam@httpc:send(Req@1) of
                {ok, Response} ->
                    case erlang:element(2, Response) of
                        200 ->
                            {ok, erlang:element(4, Response)};

                        Code ->
                            {error, firebase_error_message(Code, erlang:element(4, Response))}
                    end;

                {error, Error} ->
                    {error, <<"Firebase request failed: "/utf8, (gleam@string:inspect(Error))/binary>>}
            end;

        _value ->
            erlang:error(#{
                gleam_error => let_assert,
                message => ~"Pattern match failed, no pattern matched the value.",
                file => ~"src\\server\\auth.gleam",
                module => ~"server/auth",
                function => ~"firebase_post",
                line => 302,
                value => _value,
                start => 11322,
                'end' => 11358,
                pattern_start => 11333,
                pattern_end => 11340
            })
    end.

-file("src\\server\\auth.gleam", 19).
-spec verify_identity(binary()) -> {ok, {binary(), binary()}} | {error, binary()}.
verify_identity(Token) ->
    case server@firebase_config:firebase_config() of
        {error, Message} ->
            {error, Message};

        {ok, Config} ->
            Body = begin
                _pipe = gleam@json:object([{~"idToken", gleam@json:string(Token)}]),
                gleam@json:to_string(_pipe)
            end,
            case firebase_post(erlang:element(2, Config), ~"/accounts:lookup", Body) of
                {ok, Text} ->
                    decode_identity_response(Text);

                {error, Message@1} ->
                    {error, Message@1}
            end
    end.

-file("src\\server\\auth.gleam", 65).
-spec verify_token(binary()) -> {ok, binary()} | {error, binary()}.
verify_token(Token) ->
    case verify_identity(Token) of
        {ok, {Uid, _}} ->
            {ok, Uid};

        {error, Message} ->
            {error, Message}
    end.

-file("src\\server\\auth.gleam", 397).
-spec failed(binary()) -> auth_result().
failed(Message) ->
    {auth_result, false, Message, ~"", ~""}.

-file("src\\server\\auth.gleam", 370).
-spec extract_optional(binary(), binary()) -> gleam@option:option(binary()).
extract_optional(Text, Field) ->
    case gleam@json:parse(Text, begin
        gleam@dynamic@decode:subfield([Field], {decoder, fun gleam@dynamic@decode:decode_string/1}, fun(Value) ->
            gleam@dynamic@decode:success(Value)
        end)
    end) of
        {ok, Value} ->
            {some, Value};

        {error, _} ->
            none
    end.

-file("src\\server\\auth.gleam", 366).
-spec extract(binary(), binary()) -> binary().
extract(Text, Field) ->
    _pipe = extract_optional(Text, Field),
    gleam@option:unwrap(_pipe, ~"").

-file("src\\server\\auth.gleam", 240).
-spec register(binary(), binary(), binary()) -> auth_result().
register(Email, Password, Nickname) ->
    case server@firebase_config:firebase_config() of
        {error, Message} ->
            failed(Message);

        {ok, Config} ->
            Body = begin
                _pipe = gleam@json:object([{~"email", gleam@json:string(Email)}, {~"password", gleam@json:string(Password)}, {~"returnSecureToken", gleam@json:bool(true)}]),
                gleam@json:to_string(_pipe)
            end,
            case firebase_post(erlang:element(2, Config), ~"/accounts:signUp", Body) of
                {ok, Text} ->
                    Token = extract(Text, ~"idToken"),
                    case Token =:= ~"" of
                        true ->
                            failed(~"Firebase registration did not return an ID token.");

                        false ->
                            Update = begin
                                _pipe@1 = gleam@json:object([{~"idToken", gleam@json:string(Token)}, {~"displayName", gleam@json:string(Nickname)}, {~"returnSecureToken", gleam@json:bool(true)}]),
                                gleam@json:to_string(_pipe@1)
                            end,
                            case firebase_post(erlang:element(2, Config), ~"/accounts:update", Update) of
                                {ok, Updated} ->
                                    Final_token = begin
                                        _pipe@2 = extract_optional(Updated, ~"idToken"),
                                        gleam@option:unwrap(_pipe@2, Token)
                                    end,
                                    Final_nickname = begin
                                        _pipe@3 = extract_optional(Updated, ~"displayName"),
                                        _pipe@4 = gleam@option:unwrap(_pipe@3, Nickname),
                                        gleam@string:trim(_pipe@4)
                                    end,
                                    case (string:length(Final_nickname) >= 3) andalso (string:length(Final_nickname) =< 24) of
                                        true ->
                                            server@firestore:save_player(Final_token, extract(Text, ~"localId"), Final_nickname),
                                            {auth_result, true, <<<<"Account created. Welcome, "/utf8, Final_nickname/binary>>/binary, "."/utf8>>, Final_nickname, Final_token};

                                        false ->
                                            failed(~"Firebase created the account but did not store a valid nickname.")
                                    end;

                                {error, Message@1} ->
                                    failed(<<"Account creation succeeded, but nickname setup failed: "/utf8, Message@1/binary>>)
                            end
                    end;

                {error, Message@2} ->
                    failed(Message@2)
            end
    end.

-file("src\\server\\auth.gleam", 380).
-spec valid_register_input(binary(), binary(), binary()) -> {ok, nil} | {error, binary()}.
valid_register_input(Email, Password, Nickname) ->
    case string:length(gleam@string:trim(Email)) >= 3 of
        false ->
            {error, ~"A valid email is required."};

        true ->
            case string:length(Password) >= 6 of
                false ->
                    {error, ~"Password must be at least 6 characters."};

                true ->
                    case (string:length(Nickname) >= 3) andalso (string:length(Nickname) =< 24) of
                        false ->
                            {error, ~"Nickname must be 3-24 characters."};

                        true ->
                            {ok, nil}
                    end
            end
    end.

-file("src\\server\\auth.gleam", 330).
-spec fallback_nickname(binary()) -> binary().
fallback_nickname(Email) ->
    Local = case gleam@string:split(Email, ~"@") of
        [First | _] ->
            gleam@string:trim(First);

        _ ->
            ~""
    end,
    case (string:length(Local) >= 3) andalso (string:length(Local) =< 24) of
        true ->
            Local;

        false ->
            ~"Player"
    end.

-file("src\\server\\auth.gleam", 170).
-spec login(binary(), binary()) -> auth_result().
login(Email, Password) ->
    case server@firebase_config:firebase_config() of
        {error, Message} ->
            failed(Message);

        {ok, Config} ->
            Body = begin
                _pipe = gleam@json:object([{~"email", gleam@json:string(Email)}, {~"password", gleam@json:string(Password)}, {~"returnSecureToken", gleam@json:bool(true)}]),
                gleam@json:to_string(_pipe)
            end,
            case firebase_post(erlang:element(2, Config), ~"/accounts:signInWithPassword", Body) of
                {ok, Text} ->
                    Token = extract(Text, ~"idToken"),
                    case Token =:= ~"" of
                        true ->
                            failed(~"Firebase login did not return an ID token.");

                        false ->
                            Nickname = begin
                                _pipe@1 = extract_optional(Text, ~"displayName"),
                                _pipe@2 = gleam@option:unwrap(_pipe@1, ~""),
                                gleam@string:trim(_pipe@2)
                            end,
                            Effective = case (string:length(Nickname) >= 3) andalso (string:length(Nickname) =< 24) of
                                true ->
                                    Nickname;

                                false ->
                                    fallback_nickname(Email)
                            end,
                            case Nickname =:= Effective of
                                true ->
                                    server@firestore:save_player(Token, extract(Text, ~"localId"), Effective),
                                    {auth_result, true, <<<<"Welcome back, "/utf8, Effective/binary>>/binary, "."/utf8>>, Effective, Token};

                                false ->
                                    Update = begin
                                        _pipe@3 = gleam@json:object([{~"idToken", gleam@json:string(Token)}, {~"displayName", gleam@json:string(Effective)}, {~"returnSecureToken", gleam@json:bool(true)}]),
                                        gleam@json:to_string(_pipe@3)
                                    end,
                                    case firebase_post(erlang:element(2, Config), ~"/accounts:update", Update) of
                                        {ok, Updated} ->
                                            Final_token = begin
                                                _pipe@4 = extract_optional(Updated, ~"idToken"),
                                                gleam@option:unwrap(_pipe@4, Token)
                                            end,
                                            Final_nickname = begin
                                                _pipe@5 = extract_optional(Updated, ~"displayName"),
                                                gleam@option:unwrap(_pipe@5, Effective)
                                            end,
                                            server@firestore:save_player(Final_token, extract(Text, ~"localId"), Final_nickname),
                                            {auth_result, true, <<<<"Welcome back, "/utf8, Final_nickname/binary>>/binary, "."/utf8>>, Final_nickname, Final_token};

                                        {error, _} ->
                                            failed(~"Your account has no valid nickname and it could not be repaired automatically.")
                                    end
                            end
                    end;

                {error, Message@1} ->
                    failed(Message@1)
            end
    end.

-file("src\\server\\auth.gleam", 341).
-spec decode_credentials(binary()) -> {ok, credentials()} | {error, binary()}.
decode_credentials(Text) ->
    Decoder = begin
        gleam@dynamic@decode:field(~"email", {decoder, fun gleam@dynamic@decode:decode_string/1}, fun(Email) ->
            gleam@dynamic@decode:field(~"password", {decoder, fun gleam@dynamic@decode:decode_string/1}, fun(Password) ->
                gleam@dynamic@decode:optional_field(~"nickname", none, gleam@dynamic@decode:optional({decoder, fun gleam@dynamic@decode:decode_string/1}), fun(Nickname) ->
                    gleam@dynamic@decode:success({credentials, Email, Password, Nickname})
                end)
            end)
        end)
    end,
    case gleam@json:parse(Text, Decoder) of
        {ok, Credentials} ->
            {ok, Credentials};

        {error, _} ->
            {error, ~"Invalid auth request."}
    end.

-file("src\\server\\auth.gleam", 111).
-spec guest(binary()) -> auth_result().
-doc(~" Anonymous developer login: creates a Firebase anonymous account (no email /
 password) and stores the given nickname as its display name so the regular
 websocket join flow (token verification) works unchanged.").
guest(Nickname) ->
    case (string:length(Nickname) >= 3) andalso (string:length(Nickname) =< 24) of
        false ->
            failed(~"Nickname must be 3-24 characters.");

        true ->
            case server@firebase_config:firebase_config() of
                {error, Message} ->
                    failed(Message);

                {ok, Config} ->
                    Body = begin
                        _pipe = gleam@json:object([{~"returnSecureToken", gleam@json:bool(true)}]),
                        gleam@json:to_string(_pipe)
                    end,
                    case firebase_post(erlang:element(2, Config), ~"/accounts:signUp", Body) of
                        {ok, Text} ->
                            Token = extract(Text, ~"idToken"),
                            Local_id = extract(Text, ~"localId"),
                            case Token =:= ~"" of
                                true ->
                                    failed(~"Firebase did not return an ID token. Is the Anonymous provider enabled in the Firebase console?");

                                false ->
                                    Update = begin
                                        _pipe@1 = gleam@json:object([{~"idToken", gleam@json:string(Token)}, {~"displayName", gleam@json:string(Nickname)}, {~"returnSecureToken", gleam@json:bool(true)}]),
                                        gleam@json:to_string(_pipe@1)
                                    end,
                                    case firebase_post(erlang:element(2, Config), ~"/accounts:update", Update) of
                                        {ok, Updated} ->
                                            Final_token = begin
                                                _pipe@2 = extract_optional(Updated, ~"idToken"),
                                                gleam@option:unwrap(_pipe@2, Token)
                                            end,
                                            Final_nickname = begin
                                                _pipe@3 = extract_optional(Updated, ~"displayName"),
                                                _pipe@4 = gleam@option:unwrap(_pipe@3, Nickname),
                                                gleam@string:trim(_pipe@4)
                                            end,
                                            case (string:length(Final_nickname) >= 3) andalso (string:length(Final_nickname) =< 24) of
                                                true ->
                                                    server@firestore:save_player(Final_token, Local_id, Final_nickname),
                                                    {auth_result, true, <<<<"Guest session started. Welcome, "/utf8, Final_nickname/binary>>/binary, "."/utf8>>, Final_nickname, Final_token};

                                                false ->
                                                    failed(~"Firebase created the guest account but did not store a valid nickname.")
                                            end;

                                        {error, Message@1} ->
                                            failed(<<"Guest account created, but nickname setup failed: "/utf8, Message@1/binary>>)
                                    end
                            end;

                        {error, Message@2} ->
                            failed(Message@2)
                    end
            end
    end.

-file("src\\server\\auth.gleam", 355).
-spec decode_guest_nickname(binary()) -> {ok, binary()} | {error, binary()}.
decode_guest_nickname(Text) ->
    Decoder = begin
        gleam@dynamic@decode:field(~"nickname", {decoder, fun gleam@dynamic@decode:decode_string/1}, fun(Nickname) ->
            gleam@dynamic@decode:success(Nickname)
        end)
    end,
    case gleam@json:parse(Text, Decoder) of
        {ok, Nickname} ->
            {ok, Nickname};

        {error, _} ->
            {error, ~"Invalid guest request."}
    end.

-file("src\\server\\auth.gleam", 76).
-spec handle(binary(), bitstring()) -> auth_result().
handle(Path, Body) ->
    case gleam@bit_array:to_string(Body) of
        {error, _} ->
            failed(~"Request body is not valid UTF-8.");

        {ok, Text} ->
            case Path of
                ~"guest" ->
                    case decode_guest_nickname(Text) of
                        {error, Message} ->
                            failed(Message);

                        {ok, Nickname} ->
                            guest(gleam@string:trim(Nickname))
                    end;

                _ ->
                    case decode_credentials(Text) of
                        {error, Message@1} ->
                            failed(Message@1);

                        {ok, Credentials} ->
                            case Path of
                                ~"login" ->
                                    login(erlang:element(2, Credentials), erlang:element(3, Credentials));

                                ~"register" ->
                                    Nickname@1 = begin
                                        _pipe = erlang:element(4, Credentials),
                                        _pipe@1 = gleam@option:unwrap(_pipe, ~""),
                                        gleam@string:trim(_pipe@1)
                                    end,
                                    case valid_register_input(erlang:element(2, Credentials), erlang:element(3, Credentials), Nickname@1) of
                                        {ok, nil} ->
                                            register(erlang:element(2, Credentials), erlang:element(3, Credentials), Nickname@1);

                                        {error, Message@2} ->
                                            failed(Message@2)
                                    end;

                                _ ->
                                    failed(~"Unknown auth action.")
                            end
                    end
            end
    end.

