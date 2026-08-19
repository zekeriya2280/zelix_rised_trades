-module(mist@internal@http@handler).
-compile([no_auto_import, nowarn_ignored, nowarn_unused_vars, nowarn_unused_function, nowarn_nomatch, inline]).
-export([initial_state/0, call/4]).
-export_type([state/0]).
-moduledoc(false).

-type state() :: {state, gleam@option:option(gleam@erlang@process:timer())}.

-file("src\\mist\\internal\\http\\handler.gleam", 26).
-spec initial_state() -> state().
-doc(false).
initial_state() ->
    {state, none}.

-file("src\\mist\\internal\\http\\handler.gleam", 96).
-spec close_or_set_timer(gleam@http@response:response(gleam@bytes_tree:bytes_tree()), mist@internal@http:connection(), gleam@erlang@process:subject(glisten@internal@handler:message(any()))) -> {ok, state()} | {error, {ok, nil} | {error, binary()}}.
-doc(false).
close_or_set_timer(Resp, Conn, Sender) ->
    case gleam@http@response:get_header(Resp, ~"connection") of
        {ok, ~"close"} ->
            _ = glisten@transport:close(erlang:element(4, Conn), erlang:element(3, Conn)),
            {error, {ok, nil}};

        _ ->
            Timer = gleam@erlang@process:send_after(Sender, 10000, {internal, close}),
            {ok, {state, {some, Timer}}}
    end.

-file("src\\mist\\internal\\http\\handler.gleam", 116).
-spec handle_file_body(gleam@http@response:response(mist@internal@http:response_data()), mist@internal@http:response_data(), mist@internal@http:connection(), mist@internal@http:http_version()) -> {ok, gleam@http@response:response(gleam@bytes_tree:bytes_tree())} | {error, glisten@socket:socket_reason()}.
-doc(false).
handle_file_body(Resp, Body, Conn, Http_version) ->
    case Body of
        {file, File_descriptor, Offset, Length} ->
            Resp@1 = begin
                _pipe = Resp,
                _pipe@1 = gleam@http@response:set_body(_pipe, gleam@bytes_tree:new()),
                _pipe@2 = mist@internal@http:add_date_header(_pipe@1),
                gleam@http@response:prepend_header(_pipe@2, ~"content-length", erlang:integer_to_binary(Length))
            end,
            Resp@2 = case Http_version of
                http1 ->
                    mist@internal@http:connection_close(Resp@1);

                _ ->
                    mist@internal@http:maybe_keep_alive(Resp@1)
            end,
            Return = begin
                _pipe@3 = Resp@2,
                _pipe@4 = fun(R) ->
                    mist@internal@encoder:response_builder(erlang:element(2, Resp@2), erlang:element(3, R), mist@internal@http:version_to_string(Http_version))
                end(_pipe@3),
                _pipe@5 = fun(_capture) ->
                    glisten@transport:send(erlang:element(4, Conn), erlang:element(3, Conn), _capture)
                end(_pipe@4),
                _pipe@6 = gleam@result:'try'(_pipe@5, fun(_) ->
                    _pipe@7 = mist@internal@file:sendfile(erlang:element(4, Conn), File_descriptor, erlang:element(3, Conn), Offset, Length, []),
                    gleam@result:map_error(_pipe@7, fun(Err) ->
                        logging:log(error, <<"Failed to send file: "/utf8, (gleam@string:inspect(Err))/binary>>),
                        badarg
                    end)
                end),
                gleam@result:replace(_pipe@6, Resp@2)
            end,
            case mist_ffi:file_close(File_descriptor) of
                {ok, _} ->
                    nil;

                {error, Reason} ->
                    logging:log(error, <<"Failed to close file: "/utf8, (mist@internal@file:error_to_string(Reason))/binary>>)
            end,
            Return;

        _value ->
            erlang:error(#{
                gleam_error => let_assert,
                message => ~"Pattern match failed, no pattern matched the value.",
                file => ~"src\\mist\\internal\\http\\handler.gleam",
                module => ~"mist/internal/http/handler",
                function => ~"handle_file_body",
                line => 122,
                value => _value,
                start => 3411,
                'end' => 3466,
                pattern_start => 3422,
                pattern_end => 3459
            })
    end.

-file("src\\mist\\internal\\http\\handler.gleam", 176).
-spec handle_bytes_tree_body(gleam@http@response:response(mist@internal@http:response_data()), gleam@bytes_tree:bytes_tree(), mist@internal@http:connection(), gleam@http@request:request(mist@internal@http:connection()), mist@internal@http:http_version()) -> {ok, gleam@http@response:response(gleam@bytes_tree:bytes_tree())} | {error, glisten@socket:socket_reason()}.
-doc(false).
handle_bytes_tree_body(Resp, Body, Conn, Req, Version) ->
    Resp@1 = begin
        _pipe = Resp,
        _pipe@1 = gleam@http@response:set_body(_pipe, Body),
        mist@internal@http:add_default_headers(_pipe@1, erlang:element(2, Req) =:= head)
    end,
    Resp@2 = case Version of
        http1 ->
            mist@internal@http:connection_close(Resp@1);

        _ ->
            mist@internal@http:maybe_keep_alive(Resp@1)
    end,
    _pipe@2 = Resp@2,
    _pipe@3 = mist@internal@encoder:to_bytes_tree(_pipe@2, mist@internal@http:version_to_string(Version)),
    _pipe@4 = fun(_capture) ->
        glisten@transport:send(erlang:element(4, Conn), erlang:element(3, Conn), _capture)
    end(_pipe@3),
    gleam@result:replace(_pipe@4, Resp@2).

-file("src\\mist\\internal\\http\\handler.gleam", 65).
-spec log_and_error(exception:exception(), glisten@socket:socket(), glisten@transport:transport(), gleam@http@request:request(mist@internal@http:connection()), mist@internal@http:http_version()) -> {ok, nil} | {error, binary()}.
-doc(false).
log_and_error(Error, Socket, Transport, Req, Version) ->
    Error_string = gleam@string:inspect(Error),
    logging:log(error, Error_string),
    Resp = begin
        _pipe = gleam@http@response:new(500),
        _pipe@1 = gleam@http@response:set_body(_pipe, gleam@bytes_tree:from_bit_array(<<"Internal Server Error"/utf8>>)),
        _pipe@2 = gleam@http@response:prepend_header(_pipe@1, ~"content-length", ~"21"),
        mist@internal@http:add_default_headers(_pipe@2, erlang:element(2, Req) =:= head)
    end,
    Resp@1 = case Version of
        http1 ->
            mist@internal@http:connection_close(Resp);

        _ ->
            mist@internal@http:maybe_keep_alive(Resp)
    end,
    _ = begin
        _pipe@3 = Resp@1,
        _pipe@4 = mist@internal@encoder:to_bytes_tree(_pipe@3, mist@internal@http:version_to_string(Version)),
        fun(_capture) ->
            glisten@transport:send(Transport, Socket, _capture)
        end(_pipe@4)
    end,
    _ = glisten@transport:close(Transport, Socket),
    {error, Error_string}.

-file("src\\mist\\internal\\http\\handler.gleam", 30).
-spec call(gleam@http@request:request(mist@internal@http:connection()), fun((gleam@http@request:request(mist@internal@http:connection())) -> gleam@http@response:response(mist@internal@http:response_data())), gleam@erlang@process:subject(glisten@internal@handler:message(any())), mist@internal@http:http_version()) -> {ok, state()} | {error, {ok, nil} | {error, binary()}}.
-doc(false).
call(Req, Handler, Sender, Version) ->
    _pipe = exception_ffi:rescue(fun() ->
        Handler(Req)
    end),
    _pipe@1 = gleam@result:map_error(_pipe, fun(_capture) ->
        log_and_error(_capture, erlang:element(3, erlang:element(4, Req)), erlang:element(4, erlang:element(4, Req)), Req, Version)
    end),
    gleam@result:'try'(_pipe@1, fun(Resp) ->
        case Resp of
            {response, _, _, websocket} ->
                {error, {ok, nil}};

            {response, _, _, server_sent_events} ->
                {error, {ok, nil}};

            {response, _, _, chunked} ->
                {error, {ok, nil}};

            {response, _, _, Body} = Resp@1 ->
                _pipe@2 = case Body of
                    {bytes, Body@1} ->
                        handle_bytes_tree_body(Resp@1, Body@1, erlang:element(4, Req), Req, Version);

                    {file, _, _, _} ->
                        handle_file_body(Resp@1, Body, erlang:element(4, Req), Version);

                    _ ->
                        erlang:error(#{
                            gleam_error => panic,
                            message => ~"This shouldn't ever happen 🤞",
                            file => ~"src\\mist\\internal\\http\\handler.gleam",
                            module => ~"mist/internal/http/handler",
                            function => ~"call",
                            line => 56
                        })
                end,
                _pipe@3 = gleam@result:replace_error(_pipe@2, {ok, nil}),
                gleam@result:'try'(_pipe@3, fun(_capture) ->
                    close_or_set_timer(_capture, erlang:element(4, Req), Sender)
                end)
        end
    end).

