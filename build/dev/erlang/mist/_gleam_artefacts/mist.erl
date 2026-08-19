-module(mist).
-compile([no_auto_import, nowarn_ignored, nowarn_unused_vars, nowarn_unused_function, nowarn_nomatch, inline]).
-export([continue/1, with_selector/2, stop/0, stop_abnormal/1, ip_address_to_string/1, connection_info_to_string/1, get_connection_info/1, send_file/3, read_body/2, stream/1, new/1, port/2, read_request_body/3, after_start/2, bind/2, with_ipv6/1, with_tls/3, start/1, supervised/1, websocket/4, send_binary_frame/2, send_text_frame/2, event/1, event_id/2, event_name/2, event_retry/2, server_sent_events/4, send_event/2, send_chunk/2, chunked/4, chunk_continue/1, chunk_stop/0, chunk_stop_abnormal/1]).
-export_type([next/2, ip_address/0, connection_info/0, response_data/0, file_error/0, read_error/0, chunk/0, chunk_state/0, tls_options/0, builder/2, port_/0, websocket_message/1, s_s_e_connection/0, s_s_e_event/0, chunk_next/1]).

-opaque next(MJA, MJB) :: {continue, MJA, gleam@option:option(gleam@erlang@process:selector(MJB))} | normal_stop | {abnormal_stop, binary()}.

-type ip_address() :: {ip_v4, integer(), integer(), integer(), integer()} | {ip_v6, integer(), integer(), integer(), integer(), integer(), integer(), integer(), integer()}.

-type connection_info() :: {connection_info, integer(), ip_address()}.

-type response_data() :: websocket | {bytes, gleam@bytes_tree:bytes_tree()} | chunked | {file, mist@internal@file:file_descriptor(), integer(), integer()} | server_sent_events.

-type file_error() :: is_dir | no_access | no_entry | unknown_file_error.

-type read_error() :: excess_body | malformed_body.

-type chunk() :: {chunk, bitstring(), fun((integer()) -> {ok, chunk()} | {error, read_error()})} | done.

-type chunk_state() :: {chunk_state, mist@internal@buffer:buffer(), mist@internal@buffer:buffer(), boolean()}.

-type tls_options() :: {cert_key_files, binary(), binary()}.

-opaque builder(MJC, MJD) :: {builder, integer(), fun((gleam@http@request:request(MJC)) -> gleam@http@response:response(MJD)), fun((integer(), gleam@http:scheme(), ip_address()) -> nil), binary(), boolean(), gleam@option:option(tls_options())}.

-type port_() :: assigned | {provided, integer()}.

-type websocket_message(MJE) :: {text, binary()} | {binary, bitstring()} | closed | shutdown | {custom, MJE}.

-opaque s_s_e_connection() :: {s_s_e_connection, mist@internal@http:connection()}.

-opaque s_s_e_event() :: {s_s_e_event, gleam@option:option(binary()), gleam@option:option(binary()), gleam@option:option(integer()), gleam@string_tree:string_tree()}.

-type chunk_next(MJF) :: {chunk_continue, MJF} | chunk_stop | {chunk_abort, binary()}.

-file("src\\mist.gleam", 53).
-spec continue(MJG) -> next(MJG, any()).
continue(State) ->
    {continue, State, none}.

-file("src\\mist.gleam", 57).
-spec with_selector(next(MJK, MJL), gleam@erlang@process:selector(MJL)) -> next(MJK, MJL).
with_selector(Next, Selector) ->
    case Next of
        {continue, State, _} ->
            {continue, State, {some, Selector}};

        _ ->
            Next
    end.

-file("src\\mist.gleam", 67).
-spec stop() -> next(any(), any()).
stop() ->
    normal_stop.

-file("src\\mist.gleam", 71).
-spec stop_abnormal(binary()) -> next(any(), any()).
stop_abnormal(Reason) ->
    {abnormal_stop, Reason}.

-file("src\\mist.gleam", 75).
-spec convert_next(next(MJZ, MKA)) -> mist@internal@next:next(MJZ, MKA).
convert_next(Next) ->
    case Next of
        {continue, State, Selector} ->
            {continue, State, Selector};

        normal_stop ->
            normal_stop;

        {abnormal_stop, Reason} ->
            {abnormal_stop, Reason}
    end.

-file("src\\mist.gleam", 106).
-spec to_glisten_ip_address(ip_address()) -> glisten:ip_address().
to_glisten_ip_address(Ip) ->
    case Ip of
        {ip_v4, A, B, C, D} ->
            {ip_v4, A, B, C, D};

        {ip_v6, A@1, B@1, C@1, D@1, E, F, G, H} ->
            {ip_v6, A@1, B@1, C@1, D@1, E, F, G, H}
    end.

-file("src\\mist.gleam", 95).
-spec ip_address_to_string(ip_address()) -> binary().
-doc(~" Convenience function for printing the `IpAddress` type. It will convert the
 IPv6 loopback to the short-hand `::1`.").
ip_address_to_string(Address) ->
    glisten:ip_address_to_string(to_glisten_ip_address(Address)).

-file("src\\mist.gleam", 99).
-spec to_mist_ip_address(glisten:ip_address()) -> ip_address().
to_mist_ip_address(Ip) ->
    case Ip of
        {ip_v4, A, B, C, D} ->
            {ip_v4, A, B, C, D};

        {ip_v6, A@1, B@1, C@1, D@1, E, F, G, H} ->
            {ip_v6, A@1, B@1, C@1, D@1, E, F, G, H}
    end.

-file("src\\mist.gleam", 117).
-spec connection_info_to_string(connection_info()) -> binary().
connection_info_to_string(Connection_info) ->
    case erlang:element(3, Connection_info) of
        {ip_v6, A, B, C, D, E, F, G, H} ->
            Blocks = begin
                _pipe = [A, B, C, D, E, F, G, H],
                _pipe@1 = gleam@list:map(_pipe, fun erlang:integer_to_binary/1),
                gleam@string:join(_pipe@1, ~":")
            end,
            <<<<<<"["/utf8, Blocks/binary>>/binary, "]:"/utf8>>/binary, (erlang:integer_to_binary(erlang:element(2, Connection_info)))/binary>>;

        {ip_v4, A@1, B@1, C@1, D@1} ->
            Blocks@1 = begin
                _pipe@2 = [A@1, B@1, C@1, D@1],
                _pipe@3 = gleam@list:map(_pipe@2, fun erlang:integer_to_binary/1),
                gleam@string:join(_pipe@3, ~".")
            end,
            <<<<Blocks@1/binary, ":"/utf8>>/binary, (erlang:integer_to_binary(erlang:element(2, Connection_info)))/binary>>
    end.

-file("src\\mist.gleam", 139).
-spec get_connection_info(mist@internal@http:connection()) -> {ok, connection_info()} | {error, nil}.
-doc(~" Tries to get the IP address and port of a connected client.").
get_connection_info(Conn) ->
    _pipe = glisten@transport:peername(erlang:element(4, Conn), erlang:element(3, Conn)),
    gleam@result:map(_pipe, fun(Pair) ->
        {connection_info, erlang:element(2, Pair), begin
            _pipe@1 = erlang:element(1, Pair),
            _pipe@2 = glisten:convert_ip_address(_pipe@1),
            to_mist_ip_address(_pipe@2)
        end}
    end).

-file("src\\mist.gleam", 175).
-spec convert_file_errors(mist@internal@file:file_error()) -> file_error().
convert_file_errors(Err) ->
    case Err of
        is_dir ->
            is_dir;

        no_access ->
            no_access;

        no_entry ->
            no_entry;

        unknown_file_error ->
            unknown_file_error
    end.

-file("src\\mist.gleam", 189).
-spec send_file(binary(), integer(), gleam@option:option(integer())) -> {ok, response_data()} | {error, file_error()}.
-doc(~" To respond with a file using Erlang's `sendfile`, use this function
 with the specified offset and limit (optional). It will attempt to open the
 file for reading, get its file size, and then send the file.  If the read
 errors, this will return the relevant `FileError`. Generally, this will be
 more memory efficient than manually doing this process with `mist.Bytes`.").
send_file(Path, Offset, Limit) ->
    _pipe = Path,
    _pipe@1 = gleam_stdlib:identity(_pipe),
    _pipe@2 = mist@internal@file:stat(_pipe@1),
    _pipe@3 = gleam@result:map_error(_pipe@2, fun convert_file_errors/1),
    gleam@result:map(_pipe@3, fun(Stat) ->
        Length = case Limit of
            {some, Value} when (Value + Offset) > erlang:element(3, Stat) ->
                erlang:element(3, Stat) - Offset;

            {some, Value@1} ->
                Value@1;

            none ->
                erlang:element(3, Stat) - Offset
        end,
        {file, erlang:element(2, Stat), Offset, Length}
    end).

-file("src\\mist.gleam", 220).
-spec read_body(gleam@http@request:request(mist@internal@http:connection()), integer()) -> {ok, gleam@http@request:request(bitstring())} | {error, read_error()}.
-doc(~" The request body is not pulled from the socket until requested. The
 `content-length` header is used to determine whether the socket is read
 from or not. The read may also fail, and a `ReadError` is raised.").
read_body(Req, Max_body_limit) ->
    _pipe = Req,
    _pipe@1 = gleam@http@request:get_header(_pipe, ~"content-length"),
    _pipe@2 = gleam@result:'try'(_pipe@1, fun gleam_stdlib:parse_int/1),
    _pipe@3 = gleam@result:unwrap(_pipe@2, 0),
    fun(Content_length) ->
        case Content_length of
            Value when Value =< Max_body_limit ->
                _pipe@4 = mist@internal@http:read_body(Req),
                gleam@result:replace_error(_pipe@4, malformed_body);

            _ ->
                {error, excess_body}
        end
    end(_pipe@3).

-file("src\\mist.gleam", 249).
-spec do_stream(gleam@http@request:request(mist@internal@http:connection()), mist@internal@buffer:buffer()) -> fun((integer()) -> {ok, chunk()} | {error, read_error()}).
do_stream(Req, Buffer) ->
    fun(Size) ->
        Socket = erlang:element(3, erlang:element(4, Req)),
        Transport = erlang:element(4, erlang:element(4, Req)),
        Byte_size = erlang:byte_size(erlang:element(3, Buffer)),
        case {erlang:element(2, Buffer), Byte_size} of
            {0, 0} ->
                {ok, done};

            {0, _} ->
                {Data, Rest} = mist@internal@buffer:slice(Buffer, Size),
                {ok, {chunk, Data, do_stream(Req, mist@internal@buffer:new(Rest))}};

            {_, Buffer_size} when Buffer_size >= Size ->
                {Data@1, Rest@1} = mist@internal@buffer:slice(Buffer, Size),
                New_buffer = {buffer, erlang:element(2, Buffer), Rest@1},
                {ok, {chunk, Data@1, do_stream(Req, New_buffer)}};

            {_, _} ->
                _pipe = mist@internal@http:read_data(Socket, Transport, mist@internal@buffer:empty(), invalid_body),
                _pipe@1 = gleam@result:replace_error(_pipe, malformed_body),
                gleam@result:map(_pipe@1, fun(Data@2) ->
                    Fetched_data = erlang:byte_size(Data@2),
                    New_buffer@1 = {buffer, gleam@int:max(0, erlang:element(2, Buffer) - Fetched_data), gleam@bit_array:append(erlang:element(3, Buffer), Data@2)},
                    {New_data, Rest@2} = mist@internal@buffer:slice(New_buffer@1, Size),
                    {chunk, New_data, do_stream(Req, {buffer, erlang:element(2, New_buffer@1), Rest@2})}
                end)
        end
    end.

-file("src\\mist.gleam", 314).
-spec fetch_chunks_until(glisten@socket:socket(), glisten@transport:transport(), chunk_state(), integer()) -> {ok, {bitstring(), chunk_state()}} | {error, read_error()}.
fetch_chunks_until(Socket, Transport, State, Byte_size) ->
    Data_size = erlang:byte_size(erlang:element(3, erlang:element(2, State))),
    case {erlang:element(4, State), Data_size} of
        {_, Size} when Size >= Byte_size ->
            {Value, Rest} = mist@internal@buffer:slice(erlang:element(2, State), Byte_size),
            {ok, {Value, {chunk_state, mist@internal@buffer:new(Rest), erlang:element(3, State), erlang:element(4, State)}}};

        {true, _} ->
            {ok, {erlang:element(3, erlang:element(2, State)), {chunk_state, erlang:element(2, State), erlang:element(3, State), true}}};

        {false, _} ->
            case mist@internal@http:parse_chunk(erlang:element(3, erlang:element(3, State))) of
                complete ->
                    Updated_state = {chunk_state, erlang:element(2, State), mist@internal@buffer:empty(), true},
                    fetch_chunks_until(Socket, Transport, Updated_state, Byte_size);

                {chunk, <<>>, Next_buffer} ->
                    _pipe = mist@internal@http:read_data(Socket, Transport, Next_buffer, invalid_body),
                    _pipe@1 = gleam@result:replace_error(_pipe, malformed_body),
                    gleam@result:'try'(_pipe@1, fun(New_data) ->
                        Updated_state@1 = {chunk_state, erlang:element(2, State), mist@internal@buffer:new(New_data), erlang:element(4, State)},
                        fetch_chunks_until(Socket, Transport, Updated_state@1, Byte_size)
                    end);

                {chunk, Data, Next_buffer@1} ->
                    Updated_state@1 = {chunk_state, mist@internal@buffer:append(erlang:element(2, State), Data), Next_buffer@1, erlang:element(4, State)},
                    fetch_chunks_until(Socket, Transport, Updated_state@1, Byte_size)
            end
    end.

-file("src\\mist.gleam", 294).
-spec do_stream_chunked(gleam@http@request:request(mist@internal@http:connection()), chunk_state()) -> fun((integer()) -> {ok, chunk()} | {error, read_error()}).
do_stream_chunked(Req, State) ->
    Socket = erlang:element(3, erlang:element(4, Req)),
    Transport = erlang:element(4, erlang:element(4, Req)),
    fun(Size) ->
        case fetch_chunks_until(Socket, Transport, State, Size) of
            {ok, {Data, {chunk_state, _, _, true}}} ->
                {ok, {chunk, Data, fun(_) ->
                    {ok, done}
                end}};

            {ok, {Data@1, State@1}} ->
                {ok, {chunk, Data@1, do_stream_chunked(Req, State@1)}};

            {error, _} ->
                {error, malformed_body}
        end
    end.

-file("src\\mist.gleam", 366).
-spec stream(gleam@http@request:request(mist@internal@http:connection())) -> {ok, fun((integer()) -> {ok, chunk()} | {error, read_error()})} | {error, read_error()}.
-doc(~" Rather than explicitly reading either the whole body (optionally up to
 `N` bytes), this function allows you to consume a stream of the request
 body. Any errors reading the body will propagate out, or `Chunk`s will be
 emitted. This provides a `consume` method to attempt to grab the next
 `size` chunk from the socket.").
stream(Req) ->
    Continue = begin
        _pipe = Req,
        _pipe@1 = mist@internal@http:handle_continue(_pipe),
        gleam@result:replace_error(_pipe@1, malformed_body)
    end,
    gleam@result:map(Continue, fun(_) ->
        Is_chunked = case gleam@http@request:get_header(Req, ~"transfer-encoding") of
            {ok, ~"chunked"} ->
                true;

            _ ->
                false
        end,
        case erlang:element(2, erlang:element(4, Req)) of
            {initial, Data} ->
                case Is_chunked of
                    true ->
                        State = {chunk_state, mist@internal@buffer:new(<<>>), mist@internal@buffer:new(Data), false},
                        do_stream_chunked(Req, State);

                    false ->
                        Content_length = begin
                            _pipe@2 = Req,
                            _pipe@3 = gleam@http@request:get_header(_pipe@2, ~"content-length"),
                            _pipe@4 = gleam@result:'try'(_pipe@3, fun gleam_stdlib:parse_int/1),
                            gleam@result:unwrap(_pipe@4, 0)
                        end,
                        Initial_size = erlang:byte_size(Data),
                        Buffer = {buffer, gleam@int:max(0, Content_length - Initial_size), Data},
                        do_stream(Req, Buffer)
                end;

            _value ->
                erlang:error(#{
                    gleam_error => let_assert,
                    message => ~"Pattern match failed, no pattern matched the value.",
                    file => ~"src\\mist.gleam",
                    module => ~"mist",
                    function => ~"stream",
                    line => 381,
                    value => _value,
                    start => 11891,
                    'end' => 11936,
                    pattern_start => 11902,
                    pattern_end => 11920
                })
        end
    end).

-file("src\\mist.gleam", 422).
-spec new(fun((gleam@http@request:request(MLB)) -> gleam@http@response:response(MLD))) -> builder(MLB, MLD).
-doc(~" Create a new `mist` handler with a given function. The default port is
 4000.").
new(Handler) ->
    {builder, 4000, Handler, fun(Port, Scheme, Interface) ->
        Address = case Interface of
            {ip_v6, _, _, _, _, _, _, _, _} ->
                <<<<"["/utf8, (ip_address_to_string(Interface))/binary>>/binary, "]"/utf8>>;

            _ ->
                ip_address_to_string(Interface)
        end,
        Message = <<<<<<<<<<"Listening on "/utf8, (gleam@http:scheme_to_string(Scheme))/binary>>/binary, "://"/utf8>>/binary, Address/binary>>/binary, ":"/utf8>>/binary, (erlang:integer_to_binary(Port))/binary>>,
        gleam_stdlib:println(Message)
    end, ~"localhost", false, none}.

-file("src\\mist.gleam", 447).
-spec port(builder(MLH, MLI), integer()) -> builder(MLH, MLI).
-doc(~" Assign a different listening port to the service.").
port(Builder, Port) ->
    {builder, Port, erlang:element(3, Builder), erlang:element(4, Builder), erlang:element(5, Builder), erlang:element(6, Builder), erlang:element(7, Builder)}.

-file("src\\mist.gleam", 454).
-spec read_request_body(builder(bitstring(), MLN), integer(), gleam@http@response:response(MLN)) -> builder(mist@internal@http:connection(), MLN).
-doc(~" This function allows for implicitly reading the body of requests up
 to a given size. If the size is too large, or the read fails, the provided
 `failure_response` will be sent back as the response.").
read_request_body(Builder, Bytes_limit, Failure_response) ->
    Handler = fun(Request) ->
        case read_body(Request, Bytes_limit) of
            {ok, Request@1} ->
                (erlang:element(3, Builder))(Request@1);

            {error, _} ->
                Failure_response
        end
    end,
    {builder, erlang:element(2, Builder), Handler, erlang:element(4, Builder), erlang:element(5, Builder), erlang:element(6, Builder), erlang:element(7, Builder)}.

-file("src\\mist.gleam", 470).
-spec after_start(builder(MLT, MLU), fun((integer(), gleam@http:scheme(), ip_address()) -> nil)) -> builder(MLT, MLU).
-doc(~" Override the default function to be called after the service starts. The
 default is to log a message with the listening port.").
after_start(Builder, After_start) ->
    {builder, erlang:element(2, Builder), erlang:element(3, Builder), After_start, erlang:element(5, Builder), erlang:element(6, Builder), erlang:element(7, Builder)}.

-file("src\\mist.gleam", 481).
-spec bind(builder(MLZ, MMA), binary()) -> builder(MLZ, MMA).
-doc(~" Specify an interface to listen on. This is a string that can have the
 following values: \"localhost\", a valid IPv4 address (i.e. \"127.0.0.1\"), or
 a valid IPv6 address (i.e. \"::1\"). An invalid value will cause the
 application to crash.").
bind(Builder, Interface) ->
    {builder, erlang:element(2, Builder), erlang:element(3, Builder), erlang:element(4, Builder), Interface, erlang:element(6, Builder), erlang:element(7, Builder)}.

-file("src\\mist.gleam", 490).
-spec with_ipv6(builder(MMF, MMG)) -> builder(MMF, MMG).
-doc(~" By default, `mist` will listen on `localhost` over IPv4. If you specify an
 IPv4 address to bind to, it will still only serve over IPv4. Calling this
 function will listen on both IPv4 and IPv6 for the given interface. If it is
 not supported, your application will crash. If you provide an IPv6 address
 to `mist.bind`, this function will have no effect.").
with_ipv6(Builder) ->
    {builder, erlang:element(2, Builder), erlang:element(3, Builder), erlang:element(4, Builder), erlang:element(5, Builder), true, erlang:element(7, Builder)}.

-file("src\\mist.gleam", 495).
-spec with_tls(builder(MML, MMM), binary(), binary()) -> builder(MML, MMM).
-doc(~" Use HTTPS with the provided certificate and key files.").
with_tls(Builder, Cert, Key) ->
    Certfile = mist_ffi:file_open(gleam_stdlib:identity(Cert)),
    Keyfile = mist_ffi:file_open(gleam_stdlib:identity(Key)),
    _ = case {Certfile, Keyfile} of
        {{error, _}, {error, _}} ->
            erlang:error(#{
                gleam_error => panic,
                message => ~"Certificate and key file not found",
                file => ~"src\\mist.gleam",
                module => ~"mist",
                function => ~"with_tls",
                line => 504
            });

        {{ok, _}, {error, _}} ->
            erlang:error(#{
                gleam_error => panic,
                message => ~"Key file not found",
                file => ~"src\\mist.gleam",
                module => ~"mist",
                function => ~"with_tls",
                line => 505
            });

        {{error, _}, {ok, _}} ->
            erlang:error(#{
                gleam_error => panic,
                message => ~"Certificate file not found",
                file => ~"src\\mist.gleam",
                module => ~"mist",
                function => ~"with_tls",
                line => 506
            });

        {{ok, _}, {ok, _}} ->
            nil
    end,
    {builder, erlang:element(2, Builder), erlang:element(3, Builder), erlang:element(4, Builder), erlang:element(5, Builder), erlang:element(6, Builder), {some, {cert_key_files, Cert, Key}}}.

-file("src\\mist.gleam", 513).
-spec convert_body_types(gleam@http@response:response(response_data())) -> gleam@http@response:response(mist@internal@http:response_data()).
convert_body_types(Resp) ->
    New_body = case erlang:element(4, Resp) of
        websocket ->
            websocket;

        {bytes, Data} ->
            {bytes, Data};

        {file, Descriptor, Offset, Length} ->
            {file, Descriptor, Offset, Length};

        chunked ->
            chunked;

        server_sent_events ->
            server_sent_events
    end,
    gleam@http@response:set_body(Resp, New_body).

-file("src\\mist.gleam", 532).
-spec start(builder(mist@internal@http:connection(), response_data())) -> {ok, gleam@otp@actor:started(gleam@otp@static_supervisor:supervisor())} | {error, gleam@otp@actor:start_error()}.
-doc(~" Start a `mist` service with the provided builder.").
start(Builder) ->
    Listener_name = gleam_erlang_ffi:new_name(~"glisten_listener"),
    Factory_name = gleam_erlang_ffi:new_name(~"mist_factory_supervisor"),
    _pipe = gleam@otp@static_supervisor:new(one_for_one),
    _pipe@1 = gleam@otp@static_supervisor:add(_pipe, gleam@otp@supervision:supervisor(fun() ->
        _pipe@2 = fun(Req) ->
            convert_body_types((erlang:element(3, Builder))(Req))
        end,
        _pipe@3 = mist@internal@handler:with_func(_pipe@2, Factory_name),
        _pipe@4 = fun(_capture) ->
            glisten:new(fun mist@internal@handler:init/1, _capture)
        end(_pipe@3),
        _pipe@5 = glisten:bind(_pipe@4, erlang:element(5, Builder)),
        _pipe@6 = fun(Handler) ->
            case erlang:element(6, Builder) of
                true ->
                    glisten:with_ipv6(Handler);

                false ->
                    Handler
            end
        end(_pipe@5),
        _pipe@7 = fun(Handler) ->
            case erlang:element(7, Builder) of
                {some, {cert_key_files, Certfile, Keyfile}} ->
                    _pipe@8 = Handler,
                    glisten:with_tls(_pipe@8, Certfile, Keyfile);

                _ ->
                    Handler
            end
        end(_pipe@6),
        _pipe@8 = glisten:with_listener_name(_pipe@7, Listener_name),
        _pipe@9 = glisten:start(_pipe@8, erlang:element(2, Builder)),
        gleam@result:map(_pipe@9, fun(Server) ->
            Info = glisten:get_server_info(Listener_name, 5000),
            Ip_address = to_mist_ip_address(erlang:element(3, Info)),
            Scheme = case gleam@option:is_some(erlang:element(7, Builder)) of
                true ->
                    https;

                false ->
                    http
            end,
            (erlang:element(4, Builder))(erlang:element(2, Info), Scheme, Ip_address),
            Server
        end)
    end)),
    _pipe@2 = gleam@otp@static_supervisor:add(_pipe@1, gleam@otp@supervision:supervisor(fun() ->
        _pipe@3 = gleam@otp@factory_supervisor:worker_child(fun(Start) ->
            Start()
        end),
        _pipe@4 = gleam@otp@factory_supervisor:named(_pipe@3, Factory_name),
        _pipe@5 = gleam@otp@factory_supervisor:restart_strategy(_pipe@4, temporary),
        gleam@otp@factory_supervisor:start(_pipe@5)
    end)),
    gleam@otp@static_supervisor:start(_pipe@2).

-file("src\\mist.gleam", 585).
-spec supervised(builder(mist@internal@http:connection(), response_data())) -> gleam@otp@supervision:child_specification(gleam@otp@static_supervisor:supervisor()).
-doc(~" Start the `mist` supervisor as a child of a supervision tree.").
supervised(Builder) ->
    gleam@otp@supervision:supervisor(fun() ->
        start(Builder)
    end).

-file("src\\mist.gleam", 600).
-spec internal_to_public_ws_message(mist@internal@websocket:handler_message(MNB)) -> {ok, websocket_message(MNB)} | {error, nil}.
internal_to_public_ws_message(Msg) ->
    case Msg of
        {internal, {data, {text_frame, Data}}} ->
            _pipe = Data,
            _pipe@1 = gleam@bit_array:to_string(_pipe),
            gleam@result:map(_pipe@1, fun(_value) ->
                {text, _value}
            end);

        {internal, {data, {binary_frame, Data@1}}} ->
            {ok, {binary, Data@1}};

        {user, Msg@1} ->
            {ok, {custom, Msg@1}};

        _ ->
            {error, nil}
    end.

-file("src\\mist.gleam", 625).
-spec websocket(gleam@http@request:request(mist@internal@http:connection()), fun((MNH, websocket_message(MNI), mist@internal@websocket:websocket_connection()) -> next(MNH, MNI)), fun((mist@internal@websocket:websocket_connection()) -> {MNH, gleam@option:option(gleam@erlang@process:selector(MNI))}), fun((MNH) -> nil)) -> gleam@http@response:response(response_data()).
-doc(~" Upgrade a request to handle websockets. If the request is
 malformed, or the websocket process fails to initialize, an empty
 400 response will be sent to the client.

 The `on_init` method will be called when the actual WebSocket process
 is started, and the return value is the initial state and an optional
 selector for receiving user messages.

 The `on_close` method is called when the WebSocket process shuts down
 for any reason, valid or otherwise.").
websocket(Request, Handler, On_init, On_close) ->
    Handler@1 = fun(State, Message, Connection) ->
        _pipe = Message,
        _pipe@1 = internal_to_public_ws_message(_pipe),
        _pipe@2 = gleam@result:map(_pipe@1, fun(_capture) ->
            Handler(State, _capture, Connection)
        end),
        _pipe@3 = gleam@result:unwrap(_pipe@2, continue(State)),
        convert_next(_pipe@3)
    end,
    Extensions = begin
        _pipe = Request,
        _pipe@1 = gleam@http@request:get_header(_pipe, ~"sec-websocket-extensions"),
        _pipe@2 = gleam@result:map(_pipe@1, fun(Header) ->
            gleam@string:split(Header, ~";")
        end),
        gleam@result:unwrap(_pipe@2, [])
    end,
    Socket = erlang:element(3, erlang:element(4, Request)),
    Transport = erlang:element(4, erlang:element(4, Request)),
    case mist@internal@http:upgrade(Socket, Transport, Extensions, Request) of
        {ok, _} ->
            Start = fun() ->
                mist@internal@websocket:initialize_connection(On_init, On_close, Handler@1, Socket, Transport, Extensions)
            end,
            Factory_supervisor = gleam@otp@factory_supervisor:get_by_name(erlang:element(5, erlang:element(4, Request))),
            case gleam@otp@factory_supervisor:start_child(Factory_supervisor, Start) of
                {ok, Started} ->
                    case glisten@transport:controlling_process(Transport, Socket, erlang:element(3, Started)) of
                        {ok, _} ->
                            mist@internal@websocket:set_active(Transport, Socket),
                            _pipe@3 = gleam@http@response:new(200),
                            gleam@http@response:set_body(_pipe@3, websocket);

                        _value ->
                            erlang:error(#{
                                gleam_error => let_assert,
                                message => ~"Pattern match failed, no pattern matched the value.",
                                file => ~"src\\mist.gleam",
                                module => ~"mist",
                                function => ~"websocket",
                                line => 664,
                                value => _value,
                                start => 20644,
                                'end' => 20737,
                                pattern_start => 20655,
                                pattern_end => 20660
                            })
                    end;

                {error, Start_error} ->
                    Msg = case Start_error of
                        init_timeout ->
                            ~"init timed out";

                        {init_failed, Reason} ->
                            <<"init failed: "/utf8, Reason/binary>>;

                        {init_exited, normal} ->
                            ~"init exited normally";

                        {init_exited, killed} ->
                            ~"init killed";

                        {init_exited, {abnormal, _}} ->
                            ~"init exited abnormally"
                    end,
                    logging:log(error, <<"Failed to start WebSocket process: "/utf8, Msg/binary>>),
                    _pipe@4 = gleam@http@response:new(400),
                    gleam@http@response:set_body(_pipe@4, {bytes, gleam@bytes_tree:new()})
            end;

        {error, _} ->
            _pipe@5 = gleam@http@response:new(400),
            gleam@http@response:set_body(_pipe@5, {bytes, gleam@bytes_tree:new()})
    end.

-file("src\\mist.gleam", 698).
-spec send_binary_frame(mist@internal@websocket:websocket_connection(), bitstring()) -> {ok, nil} | {error, glisten@socket:socket_reason()}.
-doc(~" Sends a binary frame across the websocket.").
send_binary_frame(Connection, Frame) ->
    Binary_frame = exception_ffi:rescue(fun() ->
        gramps@websocket:encode_binary_frame(Frame, erlang:element(4, Connection), none)
    end),
    case Binary_frame of
        {ok, Binary_frame@1} ->
            glisten@transport:send(erlang:element(3, Connection), erlang:element(2, Connection), Binary_frame@1);

        {error, _} ->
            logging:log(error, ~"Cannot send messages from a different process than the WebSocket"),
            erlang:error(#{
                gleam_error => panic,
                message => ~"Exiting due to sending WebSocket message from non-owning process",
                file => ~"src\\mist.gleam",
                module => ~"mist",
                function => ~"send_binary_frame",
                line => 715
            })
    end.

-file("src\\mist.gleam", 721).
-spec send_text_frame(mist@internal@websocket:websocket_connection(), binary()) -> {ok, nil} | {error, glisten@socket:socket_reason()}.
-doc(~" Sends a text frame across the websocket.").
send_text_frame(Connection, Frame) ->
    Text_frame = exception_ffi:rescue(fun() ->
        gramps@websocket:encode_text_frame(Frame, erlang:element(4, Connection), none)
    end),
    case Text_frame of
        {ok, Text_frame@1} ->
            glisten@transport:send(erlang:element(3, Connection), erlang:element(2, Connection), Text_frame@1);

        {error, _} ->
            logging:log(error, ~"Cannot send messages from a different process than the WebSocket"),
            erlang:error(#{
                gleam_error => panic,
                message => ~"Exiting due to sending WebSocket message from non-owning process",
                file => ~"src\\mist.gleam",
                module => ~"mist",
                function => ~"send_text_frame",
                line => 738
            })
    end.

-file("src\\mist.gleam", 764).
-spec event(gleam@string_tree:string_tree()) -> s_s_e_event().
event(Data) ->
    {s_s_e_event, none, none, none, Data}.

-file("src\\mist.gleam", 769).
-spec event_id(s_s_e_event(), binary()) -> s_s_e_event().
event_id(Event, Id) ->
    {s_s_e_event, {some, Id}, erlang:element(3, Event), erlang:element(4, Event), erlang:element(5, Event)}.

-file("src\\mist.gleam", 774).
-spec event_name(s_s_e_event(), binary()) -> s_s_e_event().
event_name(Event, Name) ->
    {s_s_e_event, erlang:element(2, Event), {some, Name}, erlang:element(4, Event), erlang:element(5, Event)}.

-file("src\\mist.gleam", 779).
-spec event_retry(s_s_e_event(), integer()) -> s_s_e_event().
event_retry(Event, Retry) ->
    {s_s_e_event, erlang:element(2, Event), erlang:element(3, Event), {some, Retry}, erlang:element(5, Event)}.

-file("src\\mist.gleam", 792).
-spec server_sent_events(gleam@http@request:request(mist@internal@http:connection()), gleam@http@response:response(any()), fun((gleam@erlang@process:subject(MNW)) -> MNY), fun((MNY, MNW, s_s_e_connection()) -> gleam@otp@actor:next(MNY, MNW))) -> gleam@http@response:response(response_data()).
-doc(~" Sets up the connection for server-sent events. The initial response provided
 here will have its headers included in the SSE setup. The body is discarded.
 The `init` and `loop` parameters follow the same shape as the
 `gleam/otp/actor` module.

 NOTE:  There is no proper way within the spec for the server to \"close\" the
 SSE connection. There are ways around it.

 See:  `examples/eventz` for a sample usage.").
server_sent_events(Req, Resp, Init, Loop) ->
    With_default_headers = begin
        _pipe = Resp,
        _pipe@1 = gleam@http@response:set_header(_pipe, ~"content-type", ~"text/event-stream"),
        _pipe@2 = gleam@http@response:set_header(_pipe@1, ~"cache-control", ~"no-cache"),
        gleam@http@response:set_header(_pipe@2, ~"connection", ~"keep-alive")
    end,
    case glisten@transport:send(erlang:element(4, erlang:element(4, Req)), erlang:element(3, erlang:element(4, Req)), mist@internal@encoder:response_builder(200, erlang:element(3, With_default_headers), ~"1.1")) of
        {ok, _} ->
            Start = fun() ->
                _pipe@3 = gleam@otp@actor:new_with_initialiser(1000, fun(Subj) ->
                    _pipe@4 = Init(Subj),
                    _pipe@5 = gleam@otp@actor:initialised(_pipe@4),
                    _pipe@6 = gleam@otp@actor:returning(_pipe@5, erlang:self()),
                    _pipe@7 = gleam@otp@actor:selecting(_pipe@6, begin
                        _pipe@8 = gleam_erlang_ffi:new_selector(),
                        gleam@erlang@process:select(_pipe@8, Subj)
                    end),
                    {ok, _pipe@7}
                end),
                _pipe@4 = gleam@otp@actor:on_message(_pipe@3, fun(State, Message) ->
                    Loop(State, Message, {s_s_e_connection, erlang:element(4, Req)})
                end),
                _pipe@5 = gleam@otp@actor:start(_pipe@4),
                gleam@result:map(_pipe@5, fun(Started) ->
                    Pid = erlang:element(3, Started),
                    {started, Pid, Pid}
                end)
            end,
            Factory_supervisor = gleam@otp@factory_supervisor:get_by_name(erlang:element(5, erlang:element(4, Req))),
            case gleam@otp@factory_supervisor:start_child(Factory_supervisor, Start) of
                {ok, Started} ->
                    case glisten@transport:controlling_process(erlang:element(4, erlang:element(4, Req)), erlang:element(3, erlang:element(4, Req)), erlang:element(3, Started)) of
                        {ok, _} ->
                            _pipe@3 = gleam@http@response:new(200),
                            gleam@http@response:set_body(_pipe@3, server_sent_events);

                        _value ->
                            erlang:error(#{
                                gleam_error => let_assert,
                                message => ~"Pattern match failed, no pattern matched the value.",
                                file => ~"src\\mist.gleam",
                                module => ~"mist",
                                function => ~"server_sent_events",
                                line => 832,
                                value => _value,
                                start => 26099,
                                'end' => 26270,
                                pattern_start => 26110,
                                pattern_end => 26118
                            })
                    end;

                {error, _} ->
                    logging:log(error, ~"Failed to start SSE process"),
                    _pipe@4 = gleam@http@response:new(400),
                    gleam@http@response:set_body(_pipe@4, {bytes, gleam@bytes_tree:new()})
            end;

        {error, _} ->
            _pipe@5 = gleam@http@response:new(400),
            gleam@http@response:set_body(_pipe@5, {bytes, gleam@bytes_tree:new()})
    end.

-file("src\\mist.gleam", 859).
-spec send_event(s_s_e_connection(), s_s_e_event()) -> {ok, nil} | {error, nil}.
send_event(Conn, Event) ->
    {s_s_e_connection, Conn@1} = Conn,
    Id = begin
        _pipe = erlang:element(2, Event),
        _pipe@1 = gleam@option:map(_pipe, fun(Id@1) ->
            <<<<"id: "/utf8, Id@1/binary>>/binary, "\n"/utf8>>
        end),
        gleam@option:unwrap(_pipe@1, ~"")
    end,
    Event_name = begin
        _pipe@2 = erlang:element(3, Event),
        _pipe@3 = gleam@option:map(_pipe@2, fun(Name) ->
            <<<<"event: "/utf8, Name/binary>>/binary, "\n"/utf8>>
        end),
        gleam@option:unwrap(_pipe@3, ~"")
    end,
    Retry = begin
        _pipe@4 = erlang:element(4, Event),
        _pipe@5 = gleam@option:map(_pipe@4, fun(Retry@1) ->
            <<<<"retry: "/utf8, (erlang:integer_to_binary(Retry@1))/binary>>/binary, "\n"/utf8>>
        end),
        gleam@option:unwrap(_pipe@5, ~"")
    end,
    Data = begin
        _pipe@6 = erlang:element(5, Event),
        _pipe@7 = gleam@string_tree:split(_pipe@6, ~"\n"),
        _pipe@8 = gleam@list:map(_pipe@7, fun(Row) ->
            gleam@string_tree:prepend(Row, ~"data: ")
        end),
        gleam@string_tree:join(_pipe@8, ~"\n")
    end,
    Message = begin
        _pipe@9 = Data,
        _pipe@10 = gleam@string_tree:prepend(_pipe@9, Event_name),
        _pipe@11 = gleam@string_tree:prepend(_pipe@10, Id),
        _pipe@12 = gleam@string_tree:prepend(_pipe@11, Retry),
        _pipe@13 = gleam@string_tree:append(_pipe@12, ~"\n\n"),
        gleam_stdlib:wrap_list(_pipe@13)
    end,
    _pipe@14 = glisten@transport:send(erlang:element(4, Conn@1), erlang:element(3, Conn@1), Message),
    _pipe@15 = gleam@result:replace(_pipe@14, nil),
    gleam@result:replace_error(_pipe@15, nil).

-file("src\\mist.gleam", 991).
-spec int_to_hex(integer()) -> binary().
int_to_hex(Int) ->
    erlang:integer_to_list(Int, 16).

-file("src\\mist.gleam", 961).
-spec send_chunk(mist@internal@http:connection(), bitstring()) -> {ok, nil} | {error, nil}.
send_chunk(Connection, Data) ->
    Size = erlang:byte_size(Data),
    Encoded = begin
        _pipe = Size,
        _pipe@1 = int_to_hex(_pipe),
        _pipe@2 = gleam_stdlib:wrap_list(_pipe@1),
        _pipe@3 = gleam@bytes_tree:append_string(_pipe@2, ~"\r\n"),
        _pipe@4 = gleam@bytes_tree:append(_pipe@3, Data),
        gleam@bytes_tree:append_string(_pipe@4, ~"\r\n")
    end,
    _pipe@5 = glisten@transport:send(erlang:element(4, Connection), erlang:element(3, Connection), Encoded),
    gleam@result:replace_error(_pipe@5, nil).

-file("src\\mist.gleam", 898).
-spec chunked(gleam@http@request:request(mist@internal@http:connection()), gleam@http@response:response(any()), fun((gleam@erlang@process:subject(MOH)) -> MOJ), fun((MOJ, MOH, mist@internal@http:connection()) -> chunk_next(MOJ))) -> gleam@http@response:response(response_data()).
chunked(Req, Response, Init, Loop) ->
    Start = fun() ->
        _pipe = gleam@otp@actor:new_with_initialiser(1000, fun(Subj) ->
            _pipe@1 = Init(Subj),
            _pipe@2 = gleam@otp@actor:initialised(_pipe@1),
            _pipe@3 = gleam@otp@actor:returning(_pipe@2, erlang:self()),
            _pipe@4 = gleam@otp@actor:selecting(_pipe@3, begin
                _pipe@5 = gleam_erlang_ffi:new_selector(),
                gleam@erlang@process:select(_pipe@5, Subj)
            end),
            {ok, _pipe@4}
        end),
        _pipe@1 = gleam@otp@actor:on_message(_pipe, fun(State, Message) ->
            case Loop(State, Message, erlang:element(4, Req)) of
                {chunk_continue, State@1} ->
                    gleam@otp@actor:continue(State@1);

                chunk_stop ->
                    _ = case send_chunk(erlang:element(4, Req), <<>>) of
                        {ok, _} ->
                            nil;

                        {error, _} ->
                            logging:log(debug, ~"Failed to send final chunk")
                    end,
                    gleam@otp@actor:stop();

                {chunk_abort, Reason} ->
                    gleam@otp@actor:stop_abnormal(Reason)
            end
        end),
        _pipe@2 = gleam@otp@actor:start(_pipe@1),
        gleam@result:map(_pipe@2, fun(Started) ->
            {started, erlang:element(3, Started), erlang:element(3, Started)}
        end)
    end,
    Headers = [{~"transfer-encoding", ~"chunked"} | erlang:element(3, Response)],
    Initial_payload = mist@internal@encoder:response_builder(erlang:element(2, Response), Headers, mist@internal@http:version_to_string(http11)),
    case glisten@transport:send(erlang:element(4, erlang:element(4, Req)), erlang:element(3, erlang:element(4, Req)), Initial_payload) of
        {ok, _} ->
            Factory_supervisor = gleam@otp@factory_supervisor:get_by_name(erlang:element(5, erlang:element(4, Req))),
            case gleam@otp@factory_supervisor:start_child(Factory_supervisor, Start) of
                {ok, Started} ->
                    case glisten@transport:controlling_process(erlang:element(4, erlang:element(4, Req)), erlang:element(3, erlang:element(4, Req)), erlang:element(3, Started)) of
                        {ok, _} ->
                            _pipe = gleam@http@response:new(200),
                            gleam@http@response:set_body(_pipe, chunked);

                        _value ->
                            erlang:error(#{
                                gleam_error => let_assert,
                                message => ~"Pattern match failed, no pattern matched the value.",
                                file => ~"src\\mist.gleam",
                                module => ~"mist",
                                function => ~"chunked",
                                line => 946,
                                value => _value,
                                start => 29525,
                                'end' => 29683,
                                pattern_start => 29536,
                                pattern_end => 29551
                            })
                    end;

                {error, _} ->
                    logging:log(error, ~"Failed to start chunked response process"),
                    _pipe@1 = gleam@http@response:new(400),
                    gleam@http@response:set_body(_pipe@1, {bytes, gleam@bytes_tree:new()})
            end;

        _value@1 ->
            erlang:error(#{
                gleam_error => let_assert,
                message => ~"Pattern match failed, no pattern matched the value.",
                file => ~"src\\mist.gleam",
                module => ~"mist",
                function => ~"chunked",
                line => 939,
                value => _value@1,
                start => 29275,
                'end' => 29369,
                pattern_start => 29286,
                pattern_end => 29294
            })
    end.

-file("src\\mist.gleam", 975).
-spec chunk_continue(MOO) -> chunk_next(MOO).
chunk_continue(State) ->
    {chunk_continue, State}.

-file("src\\mist.gleam", 979).
-spec chunk_stop() -> chunk_next(any()).
chunk_stop() ->
    chunk_stop.

-file("src\\mist.gleam", 983).
-spec chunk_stop_abnormal(binary()) -> chunk_next(any()).
chunk_stop_abnormal(Reason) ->
    {chunk_abort, Reason}.

