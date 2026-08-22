-module(server@auth).
-compile([no_auto_import, nowarn_ignored, nowarn_unused_vars, nowarn_unused_function, nowarn_nomatch, inline]).
-export([verify_identity/1, verify_token/1, handle/2]).
-export_type([auth_result/0, credentials/0]).

-type auth_result() :: {auth_result, boolean(), binary(), binary(), binary()}.

-type credentials() :: {credentials, binary(), binary(), gleam@option:option(binary())}.

-file("src\\server\\auth.gleam", 146).
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

-file("src\\server\\auth.gleam", 74).
-spec api_key() -> binary().
api_key() ->
    _pipe = game_server_os_ffi:get_env(~"FIREBASE_WEB_API_KEY"),
    gleam@result:unwrap(_pipe, ~"").

-file("src\\server\\auth.gleam", 119).
-spec firebase_post(binary(), binary()) -> {ok, binary()} | {error, binary()}.
firebase_post(Path, Body) ->
    Url = <<<<<<"https://identitytoolkit.googleapis.com/v1"/utf8, Path/binary>>/binary, "?key="/utf8>>/binary, (api_key())/binary>>,
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
                            {error, <<<<<<"Firebase request failed ("/utf8, (erlang:integer_to_binary(Code))/binary>>/binary, "): "/utf8>>/binary, (erlang:element(4, Response))/binary>>}
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
                line => 121,
                value => _value,
                start => 4593,
                'end' => 4629,
                pattern_start => 4604,
                pattern_end => 4611
            })
    end.

-file("src\\server\\auth.gleam", 17).
-spec verify_identity(binary()) -> {ok, {binary(), binary()}} | {error, binary()}.
verify_identity(Token) ->
    case api_key() of
        ~"" ->
            {error, ~"FIREBASE_WEB_API_KEY is not configured on the server."};

        _ ->
            Body = begin
                _pipe = gleam@json:object([{~"idToken", gleam@json:string(Token)}]),
                gleam@json:to_string(_pipe)
            end,
            case firebase_post(~"/accounts:lookup", Body) of
                {ok, Text} ->
                    Uid = extract_optional(Text, ~"localId"),
                    Nickname = extract_optional(Text, ~"displayName"),
                    case Uid of
                        {some, Id} ->
                            Name = begin
                                _pipe@1 = Nickname,
                                _pipe@2 = gleam@option:unwrap(_pipe@1, ~""),
                                gleam@string:trim(_pipe@2)
                            end,
                            case (string:length(Name) >= 3) andalso (string:length(Name) =< 24) of
                                true ->
                                    {ok, {Id, Name}};

                                false ->
                                    {error, ~"Firebase account does not have a valid nickname."}
                            end;

                        none ->
                            {error, ~"Firebase token did not contain a user id."}
                    end;

                {error, Message} ->
                    {error, Message}
            end
    end.

-file("src\\server\\auth.gleam", 43).
-spec verify_token(binary()) -> {ok, binary()} | {error, binary()}.
verify_token(Token) ->
    case verify_identity(Token) of
        {ok, {Uid, _}} ->
            {ok, Uid};

        {error, Message} ->
            {error, Message}
    end.

-file("src\\server\\auth.gleam", 169).
-spec failed(binary()) -> auth_result().
failed(Message) ->
    {auth_result, false, Message, ~"", ~""}.

-file("src\\server\\auth.gleam", 145).
-spec extract(binary(), binary()) -> binary().
extract(Text, Field) ->
    _pipe = extract_optional(Text, Field),
    gleam@option:unwrap(_pipe, ~"").

-file("src\\server\\auth.gleam", 95).
-spec register(binary(), binary(), binary()) -> auth_result().
register(Email, Password, Nickname) ->
    case api_key() of
        ~"" ->
            failed(~"FIREBASE_WEB_API_KEY is not configured on the server.");

        _ ->
            Body = begin
                _pipe = gleam@json:object([{~"email", gleam@json:string(Email)}, {~"password", gleam@json:string(Password)}, {~"returnSecureToken", gleam@json:bool(true)}]),
                gleam@json:to_string(_pipe)
            end,
            case firebase_post(~"/accounts:signUp", Body) of
                {ok, Text} ->
                    Token = extract(Text, ~"idToken"),
                    Update = begin
                        _pipe@1 = gleam@json:object([{~"idToken", gleam@json:string(Token)}, {~"displayName", gleam@json:string(Nickname)}, {~"returnSecureToken", gleam@json:bool(true)}]),
                        gleam@json:to_string(_pipe@1)
                    end,
                    case firebase_post(~"/accounts:update", Update) of
                        {ok, Updated} ->
                            {auth_result, true, <<<<"Account created. Welcome, "/utf8, Nickname/binary>>/binary, "."/utf8>>, begin
                                _pipe@2 = extract_optional(Updated, ~"displayName"),
                                gleam@option:unwrap(_pipe@2, Nickname)
                            end, begin
                                _pipe@3 = extract_optional(Updated, ~"idToken"),
                                gleam@option:unwrap(_pipe@3, Token)
                            end};

                        {error, _} ->
                            {auth_result, true, <<<<"Account created. Welcome, "/utf8, Nickname/binary>>/binary, "."/utf8>>, Nickname, Token}
                    end;

                {error, Message} ->
                    failed(Message)
            end
    end.

-file("src\\server\\auth.gleam", 156).
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

-file("src\\server\\auth.gleam", 76).
-spec login(binary(), binary()) -> auth_result().
login(Email, Password) ->
    case api_key() of
        ~"" ->
            failed(~"FIREBASE_WEB_API_KEY is not configured on the server.");

        _ ->
            Body = begin
                _pipe = gleam@json:object([{~"email", gleam@json:string(Email)}, {~"password", gleam@json:string(Password)}, {~"returnSecureToken", gleam@json:bool(true)}]),
                gleam@json:to_string(_pipe)
            end,
            case firebase_post(~"/accounts:signInWithPassword", Body) of
                {ok, Text} ->
                    Token = extract(Text, ~"idToken"),
                    Nickname = begin
                        _pipe@1 = extract_optional(Text, ~"displayName"),
                        gleam@option:unwrap(_pipe@1, Email)
                    end,
                    {auth_result, true, <<<<"Welcome back, "/utf8, Nickname/binary>>/binary, "."/utf8>>, Nickname, Token};

                {error, Message} ->
                    failed(Message)
            end
    end.

-file("src\\server\\auth.gleam", 132).
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

-file("src\\server\\auth.gleam", 49).
-spec handle(binary(), bitstring()) -> auth_result().
handle(Path, Body) ->
    case gleam@bit_array:to_string(Body) of
        {error, _} ->
            failed(~"Request body is not valid UTF-8.");

        {ok, Text} ->
            case decode_credentials(Text) of
                {error, Message} ->
                    failed(Message);

                {ok, Credentials} ->
                    case Path of
                        ~"login" ->
                            login(erlang:element(2, Credentials), erlang:element(3, Credentials));

                        ~"register" ->
                            Nickname = begin
                                _pipe = erlang:element(4, Credentials),
                                _pipe@1 = gleam@option:unwrap(_pipe, ~""),
                                gleam@string:trim(_pipe@1)
                            end,
                            case valid_register_input(erlang:element(2, Credentials), erlang:element(3, Credentials), Nickname) of
                                {ok, nil} ->
                                    register(erlang:element(2, Credentials), erlang:element(3, Credentials), Nickname);

                                {error, Message@1} ->
                                    failed(Message@1)
                            end;

                        _ ->
                            failed(~"Unknown auth action.")
                    end
            end
    end.

