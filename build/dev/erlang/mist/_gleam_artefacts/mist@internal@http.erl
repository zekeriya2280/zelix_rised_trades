-module(mist@internal@http).
-compile([no_auto_import, nowarn_ignored, nowarn_unused_vars, nowarn_unused_function, nowarn_nomatch, inline]).
-export([from_header/1, read_data/4, parse_headers/4, parse_chunk/1, version_to_string/1, parse_request/2, handle_continue/1, read_body/1, base64_encode/1, crypto_hash/2, upgrade_socket/2, maybe_keep_alive/1, add_date_header/1, add_default_headers/2, upgrade/4, connection_close/1, keep_alive/1, add_content_length/2]).
-export_type([response_data/0, connection/0, packet_type/0, http_uri/0, http_packet/0, decoded_packet/0, decode_error/0, chunk/0, http_version/0, parsed_request/0, body/0, sha_hash/0]).
-moduledoc(false).

-type response_data() :: websocket | {bytes, gleam@bytes_tree:bytes_tree()} | chunked | {file, mist@internal@file:file_descriptor(), integer(), integer()} | server_sent_events.

-type connection() :: {connection, body(), glisten@socket:socket(), glisten@transport:transport(), gleam@erlang@process:name(gleam@otp@factory_supervisor:message(fun(() -> {ok, gleam@otp@actor:started(gleam@erlang@process:pid_())} | {error, gleam@otp@actor:start_error()}), gleam@erlang@process:pid_()))}.

-type packet_type() :: http | httph_bin | http_bin.

-type http_uri() :: {abs_path, bitstring()}.

-type http_packet() :: {http_request, gleam@dynamic:dynamic_(), http_uri(), {integer(), integer()}} | {http_header, integer(), gleam@erlang@atom:atom_(), bitstring(), bitstring()}.

-type decoded_packet() :: {binary_data, http_packet(), bitstring()} | {end_of_headers, bitstring()} | {more_data, gleam@option:option(integer())} | {http2_upgrade, bitstring()}.

-type decode_error() :: malformed_request | invalid_method | invalid_path | unknown_header | unknown_method | invalid_body | discard_packet | no_host_header | invalid_http_version.

-type chunk() :: {chunk, bitstring(), mist@internal@buffer:buffer()} | complete.

-type http_version() :: http1 | http11.

-type parsed_request() :: {http1_request, gleam@http@request:request(connection()), http_version()} | {upgrade, bitstring()}.

-type body() :: {initial, bitstring()} | {stream, gleam@erlang@process:selector(bitstring()), bitstring(), integer(), integer()}.

-type sha_hash() :: sha.

-file("src\\mist\\internal\\http.gleam", 88).
-spec from_header(bitstring()) -> binary().
-doc(false).
from_header(Value) ->
    case gleam@bit_array:to_string(Value) of
        {ok, Value@1} ->
            string:lowercase(Value@1);

        _value ->
            erlang:error(#{
                gleam_error => let_assert,
                message => ~"Pattern match failed, no pattern matched the value.",
                file => ~"src\\mist\\internal\\http.gleam",
                module => ~"mist/internal/http",
                function => ~"from_header",
                line => 89,
                value => _value,
                start => 1916,
                'end' => 1965,
                pattern_start => 1927,
                pattern_end => 1936
            })
    end.

-file("src\\mist\\internal\\http.gleam", 123).
-spec read_data(glisten@socket:socket(), glisten@transport:transport(), mist@internal@buffer:buffer(), decode_error()) -> {ok, bitstring()} | {error, decode_error()}.
-doc(false).
read_data(Socket, Transport, Buffer, Error) ->
    To_read = gleam@int:min(erlang:element(2, Buffer), 1000000),
    Timeout = 15000,
    gleam@result:'try'(begin
        _pipe = Socket,
        _pipe@1 = fun(_capture) ->
            glisten@transport:receive_timeout(Transport, _capture, To_read, Timeout)
        end(_pipe),
        gleam@result:replace_error(_pipe@1, Error)
    end, fun(Data) ->
        Next_buffer = {buffer, gleam@int:max(0, erlang:element(2, Buffer) - To_read), <<(erlang:element(3, Buffer))/bitstring, Data/bitstring>>},
        case erlang:element(2, Next_buffer) > 0 of
            true ->
                read_data(Socket, Transport, Next_buffer, Error);

            false ->
                {ok, erlang:element(3, Next_buffer)}
        end
    end).

-file("src\\mist\\internal\\http.gleam", 94).
-spec parse_headers(bitstring(), glisten@socket:socket(), glisten@transport:transport(), gleam@dict:dict(binary(), binary())) -> {ok, {gleam@dict:dict(binary(), binary()), bitstring()}} | {error, decode_error()}.
-doc(false).
parse_headers(Bs, Socket, Transport, Headers) ->
    case mist_ffi:decode_packet(httph_bin, Bs, []) of
        {ok, {binary_data, {http_header, _, _, Field, Value}, Rest}} ->
            Field@1 = from_header(Field),
            case gleam@bit_array:to_string(Value) of
                {ok, Value@1} ->
                    _pipe = Headers,
                    _pipe@1 = gleam@dict:insert(_pipe, Field@1, Value@1),
                    fun(_capture) ->
                        parse_headers(Rest, Socket, Transport, _capture)
                    end(_pipe@1);

                _value ->
                    erlang:error(#{
                        gleam_error => let_assert,
                        message => ~"Pattern match failed, no pattern matched the value.",
                        file => ~"src\\mist\\internal\\http.gleam",
                        module => ~"mist/internal/http",
                        function => ~"parse_headers",
                        line => 103,
                        value => _value,
                        start => 2322,
                        'end' => 2371,
                        pattern_start => 2333,
                        pattern_end => 2342
                    })
            end;

        {ok, {end_of_headers, Rest@1}} ->
            {ok, {Headers, Rest@1}};

        {ok, {more_data, Size}} ->
            Amount_to_read = gleam@option:unwrap(Size, 0),
            gleam@result:'try'(read_data(Socket, Transport, {buffer, Amount_to_read, Bs}, unknown_header), fun(Next) ->
                parse_headers(Next, Socket, Transport, Headers)
            end);

        _ ->
            {error, unknown_header}
    end.

-file("src\\mist\\internal\\http.gleam", 156).
-spec parse_chunk(bitstring()) -> chunk().
-doc(false).
parse_chunk(String) ->
    case binary:split(String, <<"\r\n"/utf8>>) of
        [<<"0"/utf8>>, _] ->
            complete;

        [Chunk_size, Rest] ->
            case gleam@bit_array:to_string(Chunk_size) of
                {ok, Chunk_size@1} ->
                    case gleam@int:base_parse(Chunk_size@1, 16) of
                        {ok, Size} ->
                            Size@1 = Size * 8,
                            case Rest of
                                <<Next_chunk:Size@1/bitstring, 13/integer, 10/integer, Rest@1/bitstring>> ->
                                    {chunk, Next_chunk, mist@internal@buffer:new(Rest@1)};

                                _ ->
                                    {chunk, <<>>, mist@internal@buffer:new(String)}
                            end;

                        {error, _} ->
                            {chunk, <<>>, mist@internal@buffer:new(String)}
                    end;

                _value ->
                    erlang:error(#{
                        gleam_error => let_assert,
                        message => ~"Pattern match failed, no pattern matched the value.",
                        file => ~"src\\mist\\internal\\http.gleam",
                        module => ~"mist/internal/http",
                        function => ~"parse_chunk",
                        line => 160,
                        value => _value,
                        start => 3796,
                        'end' => 3855,
                        pattern_start => 3807,
                        pattern_end => 3821
                    })
            end;

        _ ->
            {chunk, <<>>, mist@internal@buffer:new(String)}
    end.

-file("src\\mist\\internal\\http.gleam", 186).
-spec read_chunk(glisten@socket:socket(), glisten@transport:transport(), mist@internal@buffer:buffer(), gleam@bytes_tree:bytes_tree()) -> {ok, gleam@bytes_tree:bytes_tree()} | {error, decode_error()}.
-doc(false).
read_chunk(Socket, Transport, Buffer, Body) ->
    case {erlang:element(3, Buffer), mist_ffi:binary_match(erlang:element(3, Buffer), <<13/integer, 10/integer>>)} of
        {_, {ok, {Offset, _}}} ->
            case erlang:element(3, Buffer) of
                <<Chunk:Offset/binary, _/integer, _/integer, Rest/binary>> ->
                    gleam@result:'try'(begin
                        _pipe = Chunk,
                        _pipe@1 = gleam@bit_array:to_string(_pipe),
                        _pipe@2 = gleam@result:map(_pipe@1, fun unicode:characters_to_list/1),
                        gleam@result:replace_error(_pipe@2, invalid_body)
                    end, fun(Chunk_size) ->
                        gleam@result:'try'(begin
                            _pipe@3 = mist_ffi:string_to_int(Chunk_size, 16),
                            gleam@result:replace_error(_pipe@3, invalid_body)
                        end, fun(Size) ->
                            case Size of
                                0 ->
                                    {ok, Body};

                                Size@1 ->
                                    case Rest of
                                        <<Next_chunk:Size@1/binary, 13/integer, 10/integer, Rest@1/binary>> ->
                                            read_chunk(Socket, Transport, {buffer, 0, Rest@1}, gleam@bytes_tree:append(Body, Next_chunk));

                                        _ ->
                                            gleam@result:'try'(read_data(Socket, Transport, {buffer, 0, erlang:element(3, Buffer)}, invalid_body), fun(Next) ->
                                                read_chunk(Socket, Transport, {buffer, 0, Next}, Body)
                                            end)
                                    end
                            end
                        end)
                    end);

                _value ->
                    erlang:error(#{
                        gleam_error => let_assert,
                        message => ~"Pattern match failed, no pattern matched the value.",
                        file => ~"src\\mist\\internal\\http.gleam",
                        module => ~"mist/internal/http",
                        function => ~"read_chunk",
                        line => 194,
                        value => _value,
                        start => 4679,
                        'end' => 4812,
                        pattern_start => 4690,
                        pattern_end => 4798
                    })
            end;

        {<<>> = Data, _} ->
            gleam@result:'try'(read_data(Socket, Transport, {buffer, 0, Data}, invalid_body), fun(Next) ->
                read_chunk(Socket, Transport, {buffer, 0, Next}, Body)
            end);

        {Data, {error, nil}} ->
            gleam@result:'try'(read_data(Socket, Transport, {buffer, 0, Data}, invalid_body), fun(Next) ->
                read_chunk(Socket, Transport, {buffer, 0, Next}, Body)
            end)
    end.

-file("src\\mist\\internal\\http.gleam", 250).
-spec version_to_string(http_version()) -> binary().
-doc(false).
version_to_string(Version) ->
    case Version of
        http1 ->
            ~"1.0";

        http11 ->
            ~"1.1"
    end.

-file("src\\mist\\internal\\http.gleam", 265).
-spec decode_http_method(gleam@dynamic:dynamic_()) -> {ok, gleam@http:method()} | {error, nil}.
-doc(false).
decode_http_method(Value) ->
    Options = erlang:binary_to_atom(~"OPTIONS"),
    Get = erlang:binary_to_atom(~"GET"),
    Head = erlang:binary_to_atom(~"HEAD"),
    Post = erlang:binary_to_atom(~"POST"),
    Put = erlang:binary_to_atom(~"PUT"),
    Delete = erlang:binary_to_atom(~"DELETE"),
    Trace = erlang:binary_to_atom(~"TRACE"),
    case mist_ffi:decode_atom(Value) of
        {ok, Method} when Method =:= Options ->
            {ok, options};

        {ok, Method@1} when Method@1 =:= Get ->
            {ok, get};

        {ok, Method@2} when Method@2 =:= Head ->
            {ok, head};

        {ok, Method@3} when Method@3 =:= Post ->
            {ok, post};

        {ok, Method@4} when Method@4 =:= Put ->
            {ok, put};

        {ok, Method@5} when Method@5 =:= Delete ->
            {ok, delete};

        {ok, Method@6} when Method@6 =:= Trace ->
            {ok, trace};

        _ ->
            case gleam@dynamic@decode:run(Value, {decoder, fun gleam@dynamic@decode:decode_string/1}) of
                {ok, Str} ->
                    gleam@http:parse_method(Str);

                _ ->
                    {error, nil}
            end
    end.

-file("src\\mist\\internal\\http.gleam", 292).
-spec parse_request(bitstring(), connection()) -> {ok, parsed_request()} | {error, decode_error()}.
-doc(false).
parse_request(Bs, Conn) ->
    case mist_ffi:decode_packet(http_bin, Bs, []) of
        {ok, {binary_data, {http_request, Http_method, {abs_path, Path}, Version}, Rest}} ->
            gleam@result:'try'(begin
                _pipe = Http_method,
                _pipe@1 = decode_http_method(_pipe),
                gleam@result:replace_error(_pipe@1, unknown_method)
            end, fun(Method) ->
                gleam@result:'try'(parse_headers(Rest, erlang:element(3, Conn), erlang:element(4, Conn), maps:new()), fun(_use0) ->
                    {Headers, Rest@1} = _use0,
                    gleam@result:'try'(begin
                        _pipe@2 = Path,
                        _pipe@3 = gleam@bit_array:to_string(_pipe@2),
                        gleam@result:replace_error(_pipe@3, invalid_path)
                    end, fun(Path@1) ->
                        gleam@result:'try'(begin
                            _pipe@4 = mist_ffi:get_path_and_query(Path@1),
                            gleam@result:replace_error(_pipe@4, invalid_path)
                        end, fun(_use0@1) ->
                            {Path@2, Query} = _use0@1,
                            Scheme = case erlang:element(4, Conn) of
                                ssl ->
                                    https;

                                tcp ->
                                    http
                            end,
                            gleam@result:'try'(begin
                                _pipe@5 = gleam_stdlib:map_get(Headers, ~"host"),
                                gleam@result:replace_error(_pipe@5, no_host_header)
                            end, fun(Host_header) ->
                                {Hostname, Port} = begin
                                    _pipe@6 = Host_header,
                                    _pipe@7 = gleam@string:split_once(_pipe@6, ~":"),
                                    gleam@result:unwrap(_pipe@7, {Host_header, ~""})
                                end,
                                Port@1 = case gleam_stdlib:parse_int(Port) of
                                    {ok, Port@2} ->
                                        Port@2;

                                    {error, _} ->
                                        case Scheme of
                                            https ->
                                                443;

                                            http ->
                                                80
                                        end
                                end,
                                Req = {request, Method, maps:to_list(Headers), {connection, {initial, Rest@1}, erlang:element(3, Conn), erlang:element(4, Conn), erlang:element(5, Conn)}, Scheme, Hostname, {some, Port@1}, Path@2, gleam@option:from_result(Query)},
                                case Version of
                                    {1, 0} ->
                                        {ok, {http1_request, Req, http1}};

                                    {1, 1} ->
                                        {ok, {http1_request, Req, http11}};

                                    _ ->
                                        {error, invalid_http_version}
                                end
                            end)
                        end)
                    end)
                end)
            end);

        {ok, {http2_upgrade, <<13/integer, 10/integer, 83/integer, 77/integer, 13/integer, 10/integer, 13/integer, 10/integer, Data/bitstring>>}} ->
            {ok, {upgrade, Data}};

        {ok, {more_data, Size}} ->
            Amount_to_read = gleam@option:unwrap(Size, 0),
            gleam@result:'try'(read_data(erlang:element(3, Conn), erlang:element(4, Conn), {buffer, Amount_to_read, Bs}, malformed_request), fun(Next) ->
                parse_request(Next, Conn)
            end);

        _ ->
            {error, discard_packet}
    end.

-file("src\\mist\\internal\\http.gleam", 631).
-spec is_continue(gleam@http@request:request(connection())) -> boolean().
-doc(false).
is_continue(Req) ->
    _pipe = erlang:element(3, Req),
    _pipe@1 = gleam@list:find(_pipe, fun(Tup) ->
        (gleam@pair:first(Tup) =:= ~"expect") andalso (gleam@pair:second(Tup) =:= ~"100-continue")
    end),
    gleam@result:is_ok(_pipe@1).

-file("src\\mist\\internal\\http.gleam", 639).
-spec handle_continue(gleam@http@request:request(connection())) -> {ok, nil} | {error, decode_error()}.
-doc(false).
handle_continue(Req) ->
    case is_continue(Req) of
        true ->
            _pipe = gleam@http@response:new(100),
            _pipe@1 = gleam@http@response:set_body(_pipe, gleam@bytes_tree:new()),
            _pipe@2 = mist@internal@encoder:to_bytes_tree(_pipe@1, ~"1.1"),
            _pipe@3 = fun(_capture) ->
                glisten@transport:send(erlang:element(4, erlang:element(4, Req)), erlang:element(3, erlang:element(4, Req)), _capture)
            end(_pipe@2),
            gleam@result:replace_error(_pipe@3, malformed_request);

        false ->
            {ok, nil}
    end.

-file("src\\mist\\internal\\http.gleam", 395).
-spec read_body(gleam@http@request:request(connection())) -> {ok, gleam@http@request:request(bitstring())} | {error, decode_error()}.
-doc(false).
read_body(Req) ->
    Transport = case erlang:element(5, Req) of
        https ->
            ssl;

        http ->
            tcp
    end,
    case {gleam@http@request:get_header(Req, ~"transfer-encoding"), erlang:element(2, erlang:element(4, Req))} of
        {{ok, ~"chunked"}, {initial, Rest}} ->
            gleam@result:'try'(handle_continue(Req), fun(_) ->
                gleam@result:'try'(read_chunk(erlang:element(3, erlang:element(4, Req)), Transport, {buffer, 0, Rest}, gleam@bytes_tree:new()), fun(Chunk) ->
                    {ok, gleam@http@request:set_body(Req, erlang:list_to_bitstring(Chunk))}
                end)
            end);

        {_, {initial, Rest@1}} ->
            gleam@result:'try'(handle_continue(Req), fun(_) ->
                Body_size = begin
                    _pipe = erlang:element(3, Req),
                    _pipe@1 = gleam@list:find(_pipe, fun(Tup) ->
                        gleam@pair:first(Tup) =:= ~"content-length"
                    end),
                    _pipe@2 = gleam@result:map(_pipe@1, fun gleam@pair:second/1),
                    _pipe@3 = gleam@result:'try'(_pipe@2, fun gleam_stdlib:parse_int/1),
                    gleam@result:unwrap(_pipe@3, 0)
                end,
                Remaining = Body_size - erlang:byte_size(Rest@1),
                _pipe@4 = case {Body_size, Remaining} of
                    {0, 0} ->
                        {ok, <<>>};

                    {0, _} ->
                        {ok, Rest@1};

                    {_, 0} ->
                        {ok, Rest@1};

                    {_, _} ->
                        read_data(erlang:element(3, erlang:element(4, Req)), Transport, {buffer, Remaining, Rest@1}, invalid_body)
                end,
                _pipe@5 = gleam@result:map(_pipe@4, fun(_capture) ->
                    gleam@http@request:set_body(Req, _capture)
                end),
                gleam@result:replace_error(_pipe@5, invalid_body)
            end);

        {_, {stream, Selector, Data, Remaining, Attempts}} when Remaining > 0 ->
            Res = begin
                _pipe = Selector,
                _pipe@1 = gleam_erlang_ffi:select(_pipe, 1000),
                gleam@result:replace_error(_pipe@1, invalid_body)
            end,
            gleam@result:'try'(Res, fun(Next) ->
                Got = erlang:byte_size(Next),
                Left = gleam@int:max(Remaining - Got, 0),
                New_data = gleam@bit_array:append(Data, Next),
                case Left of
                    0 ->
                        {ok, gleam@http@request:set_body(Req, New_data)};

                    _ ->
                        read_body(gleam@http@request:set_body(Req, begin
                            _record = erlang:element(4, Req),
                            {connection, {stream, Selector, New_data, Left, Attempts + 1}, erlang:element(3, _record), erlang:element(4, _record), erlang:element(5, _record)}
                        end))
                end
            end);

        {_, {stream, _, Data@1, _, _}} ->
            {ok, gleam@http@request:set_body(Req, Data@1)}
    end.

-file("src\\mist\\internal\\http.gleam", 663).
-spec base64_encode(binary()) -> binary().
-doc(false).
base64_encode(Data) ->
    base64:encode(Data).

-file("src\\mist\\internal\\http.gleam", 660).
-spec crypto_hash(sha_hash(), binary()) -> binary().
-doc(false).
crypto_hash(Hash, Data) ->
    crypto:hash(Hash, Data).

-file("src\\mist\\internal\\http.gleam", 480).
-spec parse_websocket_key(binary()) -> binary().
-doc(false).
parse_websocket_key(Key) ->
    _pipe = Key,
    _pipe@1 = gleam@string:append(_pipe, ~"258EAFA5-E914-47DA-95CA-C5AB0DC85B11"),
    _pipe@2 = fun(_capture) ->
        crypto:hash(sha, _capture)
    end(_pipe@1),
    base64:encode(_pipe@2).

-file("src\\mist\\internal\\http.gleam", 487).
-spec upgrade_socket(gleam@http@request:request(connection()), list(binary())) -> {ok, gleam@http@response:response(gleam@bytes_tree:bytes_tree())} | {error, gleam@http@request:request(connection())}.
-doc(false).
upgrade_socket(Req, Extensions) ->
    gleam@result:'try'(begin
        _pipe = gleam@http@request:get_header(Req, ~"upgrade"),
        gleam@result:replace_error(_pipe, Req)
    end, fun(_) ->
        gleam@result:'try'(begin
            _pipe@1 = gleam@http@request:get_header(Req, ~"sec-websocket-key"),
            gleam@result:replace_error(_pipe@1, Req)
        end, fun(Key) ->
            gleam@result:'try'(begin
                _pipe@2 = gleam@http@request:get_header(Req, ~"sec-websocket-version"),
                gleam@result:replace_error(_pipe@2, Req)
            end, fun(_) ->
                Permessage_deflate = gramps@websocket:has_deflate(Extensions),
                Accept_key = parse_websocket_key(Key),
                Resp = begin
                    _pipe@3 = gleam@http@response:new(101),
                    _pipe@4 = gleam@http@response:set_body(_pipe@3, gleam@bytes_tree:new()),
                    _pipe@5 = gleam@http@response:prepend_header(_pipe@4, ~"upgrade", ~"websocket"),
                    _pipe@6 = gleam@http@response:prepend_header(_pipe@5, ~"connection", ~"Upgrade"),
                    gleam@http@response:prepend_header(_pipe@6, ~"sec-websocket-accept", Accept_key)
                end,
                case Permessage_deflate of
                    true ->
                        {ok, gleam@http@response:prepend_header(Resp, ~"sec-websocket-extensions", ~"permessage-deflate")};

                    false ->
                        {ok, Resp}
                end
            end)
        end)
    end).

-file("src\\mist\\internal\\http.gleam", 565).
-spec maybe_keep_alive(gleam@http@response:response(JYL)) -> gleam@http@response:response(JYL).
-doc(false).
maybe_keep_alive(Resp) ->
    case gleam@http@response:get_header(Resp, ~"connection") of
        {ok, _} ->
            Resp;

        _ ->
            gleam@http@response:set_header(Resp, ~"connection", ~"keep-alive")
    end.

-file("src\\mist\\internal\\http.gleam", 572).
-spec maybe_drop_body(gleam@http@response:response(gleam@bytes_tree:bytes_tree()), boolean()) -> gleam@http@response:response(gleam@bytes_tree:bytes_tree()).
-doc(false).
maybe_drop_body(Resp, Is_head_request) ->
    case Is_head_request of
        true ->
            gleam@http@response:set_body(Resp, gleam@bytes_tree:new());

        false ->
            Resp
    end.

-file("src\\mist\\internal\\http.gleam", 550).
-spec add_date_header(gleam@http@response:response(JYC)) -> gleam@http@response:response(JYC).
-doc(false).
add_date_header(Resp) ->
    case gleam@http@response:get_header(Resp, ~"date") of
        {error, _} ->
            gleam@http@response:set_header(Resp, ~"date", mist@internal@clock:get_date());

        _ ->
            Resp
    end.

-file("src\\mist\\internal\\http.gleam", 602).
-spec add_default_headers(gleam@http@response:response(gleam@bytes_tree:bytes_tree()), boolean()) -> gleam@http@response:response(gleam@bytes_tree:bytes_tree()).
-doc(false).
add_default_headers(Resp, Is_head_response) ->
    Body_size = erlang:iolist_size(erlang:element(4, Resp)),
    {_, Headers} = begin
        _pipe = erlang:element(3, Resp),
        _pipe@1 = gleam@list:key_pop(_pipe, ~"content-length"),
        gleam@result:lazy_unwrap(_pipe@1, fun() ->
            {~"", erlang:element(3, Resp)}
        end)
    end,
    Resp@1 = case {erlang:element(2, Resp), Body_size} of
        {N, _} when (N >= 100) andalso (N =< 199) ->
            {response, erlang:element(2, Resp), Headers, erlang:element(4, Resp)};

        {N@1, _} when N@1 =:= 204 ->
            {response, erlang:element(2, Resp), Headers, erlang:element(4, Resp)};

        {N@2, 0} when N@2 =:= 304 ->
            Resp;

        {_, 0} when Is_head_response =:= true ->
            Resp;

        {_, _} ->
            gleam@http@response:set_header(Resp, ~"content-length", erlang:integer_to_binary(Body_size))
    end,
    _pipe@2 = Resp@1,
    _pipe@3 = add_date_header(_pipe@2),
    maybe_drop_body(_pipe@3, Is_head_response).

-file("src\\mist\\internal\\http.gleam", 527).
-spec upgrade(glisten@socket:socket(), glisten@transport:transport(), list(binary()), gleam@http@request:request(connection())) -> {ok, nil} | {error, nil}.
-doc(false).
upgrade(Socket, Transport, Extensions, Req) ->
    gleam@result:'try'(begin
        _pipe = upgrade_socket(Req, Extensions),
        gleam@result:replace_error(_pipe, nil)
    end, fun(Resp) ->
        gleam@result:'try'(begin
            _pipe@1 = Resp,
            _pipe@2 = add_default_headers(_pipe@1, erlang:element(2, Req) =:= head),
            _pipe@3 = maybe_keep_alive(_pipe@2),
            _pipe@4 = mist@internal@encoder:to_bytes_tree(_pipe@3, ~"1.1"),
            _pipe@5 = fun(_capture) ->
                glisten@transport:send(Transport, Socket, _capture)
            end(_pipe@4),
            gleam@result:replace_error(_pipe@5, nil)
        end, fun(_) ->
            {ok, nil}
        end)
    end).

-file("src\\mist\\internal\\http.gleam", 557).
-spec connection_close(gleam@http@response:response(JYF)) -> gleam@http@response:response(JYF).
-doc(false).
connection_close(Resp) ->
    gleam@http@response:set_header(Resp, ~"connection", ~"close").

-file("src\\mist\\internal\\http.gleam", 561).
-spec keep_alive(gleam@http@response:response(JYI)) -> gleam@http@response:response(JYI).
-doc(false).
keep_alive(Resp) ->
    gleam@http@response:set_header(Resp, ~"connection", ~"keep-alive").

-file("src\\mist\\internal\\http.gleam", 582).
-spec add_content_length(boolean(), integer()) -> fun((gleam@http@response:response(JYQ)) -> gleam@http@response:response(JYQ)).
-doc(false).
add_content_length(When, Length) ->
    fun(Resp) ->
        case When of
            true ->
                {_, Headers} = begin
                    _pipe = erlang:element(3, Resp),
                    _pipe@1 = gleam@list:key_pop(_pipe, ~"content-length"),
                    gleam@result:lazy_unwrap(_pipe@1, fun() ->
                        {~"", erlang:element(3, Resp)}
                    end)
                end,
                _pipe@2 = {response, erlang:element(2, Resp), Headers, erlang:element(4, Resp)},
                gleam@http@response:set_header(_pipe@2, ~"content-length", erlang:integer_to_binary(Length));

            false ->
                Resp
        end
    end.

