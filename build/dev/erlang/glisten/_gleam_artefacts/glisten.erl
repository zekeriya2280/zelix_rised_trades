-module(glisten).
-compile([no_auto_import, nowarn_ignored, nowarn_unused_vars, nowarn_unused_function, nowarn_nomatch, inline]).
-export([convert_ip_address/1, get_server_info/2, ip_address_to_string/1, get_connection_info/1, send/2, continue/1, with_selector/2, stop/0, stop_abnormal/1, convert_next/1, map_selector/2, new/2, with_close/2, with_pool_size/2, with_http2/1, bind/2, with_ipv6/1, with_tls/3, with_active_state/2, with_listener_name/2, with_connection_factory_name/2, start/2, supervised/2]).
-export_type([message/1, ip_address/0, connection_info/0, connection/1, next/2, builder/2]).

-type message(IHA) :: {packet, bitstring()} | {user, IHA}.

-type ip_address() :: {ip_v4, integer(), integer(), integer(), integer()} | {ip_v6, integer(), integer(), integer(), integer(), integer(), integer(), integer(), integer()}.

-type connection_info() :: {connection_info, integer(), ip_address()}.

-type connection(IHB) :: {connection, glisten@socket:socket(), glisten@transport:transport(), gleam@erlang@process:subject(glisten@internal@handler:message(IHB))}.

-opaque next(IHC, IHD) :: {continue, IHC, gleam@option:option(gleam@erlang@process:selector(IHD))} | normal_stop | {abnormal_stop, binary()}.

-opaque builder(IHE, IHF) :: {builder, glisten@socket@options:interface(), fun((connection(IHF)) -> {IHE, gleam@option:option(gleam@erlang@process:selector(IHF))}), fun((IHE, message(IHF), connection(IHF)) -> next(IHE, message(IHF))), gleam@option:option(fun((IHE) -> nil)), integer(), boolean(), boolean(), gleam@option:option(glisten@socket@options:tls_certs()), gleam@option:option(gleam@erlang@process:name(glisten@internal@listener:message())), gleam@option:option(gleam@erlang@process:name(gleam@otp@factory_supervisor:message(glisten@socket:socket(), gleam@erlang@process:subject(glisten@internal@handler:message(IHF))))), glisten@socket@options:active_state()}.

-file("src\\glisten.gleam", 68).
-spec convert_ip_address(glisten@socket@options:ip_address()) -> ip_address().
-doc(false).
convert_ip_address(Ip) ->
    case Ip of
        {ip_v4, A, B, C, D} ->
            {ip_v4, A, B, C, D};

        {ip_v6, A@1, B@1, C@1, D@1, E, F, G, H} ->
            {ip_v6, A@1, B@1, C@1, D@1, E, F, G, H}
    end.

-file("src\\glisten.gleam", 48).
-spec get_server_info(gleam@erlang@process:name(glisten@internal@listener:message()), integer()) -> connection_info().
-doc(~" Returns the user-provided port or the OS-assigned value if 0 was provided.").
get_server_info(Listener, Timeout) ->
    Listener@1 = gleam@erlang@process:named_subject(Listener),
    State = gleam@erlang@process:call(Listener@1, Timeout, fun(_value) ->
        {info, _value}
    end),
    {connection_info, erlang:element(3, State), convert_ip_address(erlang:element(4, State))}.

-file("src\\glisten.gleam", 97).
-spec join_ipv6_fields(list(integer())) -> binary().
join_ipv6_fields(Fields) ->
    _pipe = gleam@list:map(Fields, fun gleam@int:to_base16/1),
    gleam@string:join(_pipe, ~":").

-file("src\\glisten.gleam", 106).
-spec ipv6_zeros(list(integer()), integer(), integer(), integer(), integer()) -> {ok, {integer(), integer()}} | {error, nil}.
-doc(~" Finds the longest sequence of consecutive all-zero fields in an IPv6.
 If the address contains multiple runs of all-zero fields of the same size,
 it is the leftmost that is compressed.

 This returns the start & end indices of the compressed zeros.").
ipv6_zeros(Fields, Pos, Len, Max_start, Max_len) ->
    case Fields of
        [] when Max_len > 1 ->
            {ok, {Max_start, Max_start + Max_len}};

        [] ->
            {error, nil};

        [X | Xs] when X =:= 0 ->
            Len@1 = Len + 1,
            case Len@1 > Max_len of
                true ->
                    ipv6_zeros(Xs, Pos + 1, Len@1, (Pos + 1) - Len@1, Len@1);

                false ->
                    ipv6_zeros(Xs, Pos + 1, Len@1, Max_start, Max_len)
            end;

        [_ | Xs@1] ->
            ipv6_zeros(Xs@1, Pos + 1, 0, Max_start, Max_len)
    end.

-file("src\\glisten.gleam", 77).
-spec ip_address_to_string(ip_address()) -> binary().
-doc(~" Convenience function for convert an `IpAddress` type into a string. It will
 convert IPv6 addresses to the canonical short-hand (ie. loopback is ::1).").
ip_address_to_string(Address) ->
    case Address of
        {ip_v4, A, B, C, D} ->
            _pipe = [A, B, C, D],
            _pipe@1 = gleam@list:map(_pipe, fun erlang:integer_to_binary/1),
            gleam@string:join(_pipe@1, ~".");

        {ip_v6, A@1, B@1, C@1, D@1, E, F, G, H} ->
            Fields = [A@1, B@1, C@1, D@1, E, F, G, H],
            _pipe@2 = case ipv6_zeros(Fields, 0, 0, 0, 0) of
                {error, _} ->
                    join_ipv6_fields(Fields);

                {ok, {Start, End}} ->
                    <<<<(join_ipv6_fields(gleam@list:take(Fields, Start)))/binary, "::"/utf8>>/binary, (join_ipv6_fields(gleam@list:drop(Fields, End)))/binary>>
            end,
            string:lowercase(_pipe@2)
    end.

-file("src\\glisten.gleam", 127).
-spec get_connection_info(connection(any())) -> {ok, connection_info()} | {error, nil}.
-doc(~" Tries to read the IP address and port of a connected client.  It will
 return valid IPv4 or IPv6 addresses, attempting to return the most relevant
 one for the client.").
get_connection_info(Conn) ->
    _pipe = glisten@transport:peername(erlang:element(3, Conn), erlang:element(2, Conn)),
    gleam@result:map(_pipe, fun(Pair) ->
        {connection_info, erlang:element(2, Pair), convert_ip_address(erlang:element(1, Pair))}
    end).

-file("src\\glisten.gleam", 135).
-spec send(connection(any()), gleam@bytes_tree:bytes_tree()) -> {ok, nil} | {error, glisten@socket:socket_reason()}.
-doc(~" Sends a BytesTree message over the socket using the active transport").
send(Conn, Msg) ->
    glisten@transport:send(erlang:element(3, Conn), erlang:element(2, Conn), Msg).

-file("src\\glisten.gleam", 148).
-spec continue(IIF) -> next(IIF, any()).
continue(State) ->
    {continue, State, none}.

-file("src\\glisten.gleam", 152).
-spec with_selector(next(IIJ, IIK), gleam@erlang@process:selector(IIK)) -> next(IIJ, IIK).
with_selector(Next, Selector) ->
    case Next of
        {continue, State, _} ->
            {continue, State, {some, Selector}};

        Stop ->
            Stop
    end.

-file("src\\glisten.gleam", 162).
-spec stop() -> next(any(), any()).
stop() ->
    normal_stop.

-file("src\\glisten.gleam", 166).
-spec stop_abnormal(binary()) -> next(any(), any()).
stop_abnormal(Reason) ->
    {abnormal_stop, Reason}.

-file("src\\glisten.gleam", 171).
-spec convert_next(next(IIY, IIZ)) -> glisten@internal@handler:next(IIY, IIZ).
-doc(false).
convert_next(Next) ->
    case Next of
        {continue, State, Selector} ->
            {continue, State, Selector};

        normal_stop ->
            normal_stop;

        {abnormal_stop, Reason} ->
            {abnormal_stop, Reason}
    end.

-file("src\\glisten.gleam", 182).
-spec map_selector(next(IJE, IJF), fun((IJF) -> IJI)) -> next(IJE, IJI).
-doc(false).
map_selector(Next, Mapper) ->
    case Next of
        {continue, State, {some, Selector}} ->
            {continue, State, {some, gleam_erlang_ffi:map_selector(Selector, Mapper)}};

        {continue, State@1, none} ->
            {continue, State@1, none};

        {abnormal_stop, Reason} ->
            {abnormal_stop, Reason};

        normal_stop ->
            normal_stop
    end.

-file("src\\glisten.gleam", 222).
-spec map_user_selector(gleam@erlang@process:selector(message(IJL))) -> gleam@erlang@process:selector(glisten@internal@handler:loop_message(IJL)).
map_user_selector(Selector) ->
    gleam_erlang_ffi:map_selector(Selector, fun(Value) ->
        case Value of
            {packet, Msg} ->
                {packet, Msg};

            {user, Msg@1} ->
                {custom, Msg@1}
        end
    end).

-file("src\\glisten.gleam", 233).
-spec convert_loop(fun((IJQ, message(IJR), connection(IJR)) -> next(IJQ, message(IJR)))) -> fun((IJQ, glisten@internal@handler:loop_message(IJR), glisten@internal@handler:connection(IJR)) -> glisten@internal@handler:next(IJQ, glisten@internal@handler:loop_message(IJR))).
convert_loop(Loop) ->
    fun(Data, Msg, Conn) ->
        Conn@1 = {connection, erlang:element(3, Conn), erlang:element(4, Conn), erlang:element(5, Conn)},
        Message = case Msg of
            {packet, Msg@1} ->
                {packet, Msg@1};

            {custom, Msg@2} ->
                {user, Msg@2}
        end,
        case Loop(Data, Message, Conn@1) of
            {continue, Data@1, Selector} ->
                case Selector of
                    {some, Selector@1} ->
                        _pipe = glisten@internal@handler:continue(Data@1),
                        glisten@internal@handler:with_selector(_pipe, map_user_selector(Selector@1));

                    _ ->
                        glisten@internal@handler:continue(Data@1)
                end;

            normal_stop ->
                glisten@internal@handler:stop();

            {abnormal_stop, Reason} ->
                glisten@internal@handler:stop_abnormal(Reason)
        end
    end.

-file("src\\glisten.gleam", 257).
-spec convert_on_init(fun((connection(IJW)) -> {IJY, gleam@option:option(gleam@erlang@process:selector(IJW))})) -> fun((glisten@internal@handler:connection(IJW)) -> {IJY, gleam@option:option(gleam@erlang@process:selector(IJW))}).
convert_on_init(On_init) ->
    fun(Conn) ->
        Connection = {connection, erlang:element(3, Conn), erlang:element(4, Conn), erlang:element(5, Conn)},
        On_init(Connection)
    end.

-file("src\\glisten.gleam", 276).
-spec new(fun((connection(IKE)) -> {IKG, gleam@option:option(gleam@erlang@process:selector(IKE))}), fun((IKG, message(IKE), connection(IKE)) -> next(IKG, message(IKE)))) -> builder(IKG, IKE).
-doc(~" Create a new handler for each connection.  The required arguments mirror the
 `actor.start` API from `gleam_otp`.  The default pool is 10 accceptor
 processes.").
new(On_init, Loop) ->
    {builder, loopback, On_init, Loop, none, 10, false, false, none, none, none, once}.

-file("src\\glisten.gleam", 297).
-spec with_close(builder(IKN, IKO), fun((IKN) -> nil)) -> builder(IKN, IKO).
-doc(~" Adds a function to the handler to be called when the connection is closed.").
with_close(Builder, On_close) ->
    {builder, erlang:element(2, Builder), erlang:element(3, Builder), erlang:element(4, Builder), {some, On_close}, erlang:element(6, Builder), erlang:element(7, Builder), erlang:element(8, Builder), erlang:element(9, Builder), erlang:element(10, Builder), erlang:element(11, Builder), erlang:element(12, Builder)}.

-file("src\\glisten.gleam", 305).
-spec with_pool_size(builder(IKT, IKU), integer()) -> builder(IKT, IKU).
-doc(~" Modify the size of the acceptor pool").
with_pool_size(Builder, Size) ->
    {builder, erlang:element(2, Builder), erlang:element(3, Builder), erlang:element(4, Builder), erlang:element(5, Builder), Size, erlang:element(7, Builder), erlang:element(8, Builder), erlang:element(9, Builder), erlang:element(10, Builder), erlang:element(11, Builder), erlang:element(12, Builder)}.

-file("src\\glisten.gleam", 316).
-spec with_http2(builder(IKZ, ILA)) -> builder(IKZ, ILA).
-doc(false).
with_http2(Builder) ->
    {builder, erlang:element(2, Builder), erlang:element(3, Builder), erlang:element(4, Builder), erlang:element(5, Builder), erlang:element(6, Builder), true, erlang:element(8, Builder), erlang:element(9, Builder), erlang:element(10, Builder), erlang:element(11, Builder), erlang:element(12, Builder)}.

-file("src\\glisten.gleam", 326).
-spec bind(builder(ILF, ILG), binary()) -> builder(ILF, ILG).
-doc(~" This sets the interface for `glisten` to listen on. It accepts the following
 strings:  \"localhost\", valid IPv4 addresses (i.e. \"127.0.0.1\"), and valid
 IPv6 addresses (i.e. \"::1\"). If an invalid value is provided, this will
 panic.").
bind(Builder, Interface) ->
    Address = case {Interface, glisten_ffi:parse_address(unicode:characters_to_list(Interface))} of
        {~"0.0.0.0", _} ->
            any;

        {~"localhost", _} ->
            loopback;

        {~"127.0.0.1", _} ->
            loopback;

        {_, {ok, Address@1}} ->
            {address, Address@1};

        {_, {error, _}} ->
            erlang:error(#{
                gleam_error => panic,
                message => ~"Invalid interface provided:  must be a valid IPv4/IPv6 address, or \"localhost\"",
                file => ~"src\\glisten.gleam",
                module => ~"glisten",
                function => ~"bind",
                line => 335
            })
    end,
    {builder, Address, erlang:element(3, Builder), erlang:element(4, Builder), erlang:element(5, Builder), erlang:element(6, Builder), erlang:element(7, Builder), erlang:element(8, Builder), erlang:element(9, Builder), erlang:element(10, Builder), erlang:element(11, Builder), erlang:element(12, Builder)}.

-file("src\\glisten.gleam", 344).
-spec with_ipv6(builder(ILL, ILM)) -> builder(ILL, ILM).
-doc(~" By default, `glisten` listens on `localhost` only over IPv4.  With an IPv4
 address, you can call this builder method to also serve over IPv6 on that
 interface.  If it is not supported, your application will crash.  If you
 call this with an IPv6 interface specified, it will have no effect.").
with_ipv6(Builder) ->
    {builder, erlang:element(2, Builder), erlang:element(3, Builder), erlang:element(4, Builder), erlang:element(5, Builder), erlang:element(6, Builder), erlang:element(7, Builder), true, erlang:element(9, Builder), erlang:element(10, Builder), erlang:element(11, Builder), erlang:element(12, Builder)}.

-file("src\\glisten.gleam", 351).
-spec with_tls(builder(ILR, ILS), binary(), binary()) -> builder(ILR, ILS).
-doc(~" To use TLS, provide a path to a certficate and key file.").
with_tls(Builder, Cert, Key) ->
    {builder, erlang:element(2, Builder), erlang:element(3, Builder), erlang:element(4, Builder), erlang:element(5, Builder), erlang:element(6, Builder), erlang:element(7, Builder), erlang:element(8, Builder), {some, {cert_key_files, Cert, Key}}, erlang:element(10, Builder), erlang:element(11, Builder), erlang:element(12, Builder)}.

-file("src\\glisten.gleam", 361).
-spec with_active_state(builder(ILX, ILY), glisten@socket@options:active_state()) -> builder(ILX, ILY).
-doc(~" Set the server's `ActiveState` for flow control of received packets.
 Default is `Once`. Allowed are `Once`, `Active` and `Count(n)` where n > 1.").
with_active_state(Builder, Active_state) ->
    case Active_state of
        once ->
            {builder, erlang:element(2, Builder), erlang:element(3, Builder), erlang:element(4, Builder), erlang:element(5, Builder), erlang:element(6, Builder), erlang:element(7, Builder), erlang:element(8, Builder), erlang:element(9, Builder), erlang:element(10, Builder), erlang:element(11, Builder), Active_state};

        active ->
            {builder, erlang:element(2, Builder), erlang:element(3, Builder), erlang:element(4, Builder), erlang:element(5, Builder), erlang:element(6, Builder), erlang:element(7, Builder), erlang:element(8, Builder), erlang:element(9, Builder), erlang:element(10, Builder), erlang:element(11, Builder), Active_state};

        {count, N} when N > 1 ->
            {builder, erlang:element(2, Builder), erlang:element(3, Builder), erlang:element(4, Builder), erlang:element(5, Builder), erlang:element(6, Builder), erlang:element(7, Builder), erlang:element(8, Builder), erlang:element(9, Builder), erlang:element(10, Builder), erlang:element(11, Builder), Active_state};

        {count, _} ->
            erlang:error(#{
                gleam_error => panic,
                message => ~"Count shall be greater than 1",
                file => ~"src\\glisten.gleam",
                module => ~"glisten",
                function => ~"with_active_state",
                line => 369
            });

        passive ->
            erlang:error(#{
                gleam_error => panic,
                message => ~"You cannot set the server's `ActiveState` to `Passive`",
                file => ~"src\\glisten.gleam",
                module => ~"glisten",
                function => ~"with_active_state",
                line => 371
            })
    end.

-file("src\\glisten.gleam", 376).
-spec with_listener_name(builder(IMD, IME), gleam@erlang@process:name(glisten@internal@listener:message())) -> builder(IMD, IME).
-doc(false).
with_listener_name(Builder, Listener_name) ->
    {builder, erlang:element(2, Builder), erlang:element(3, Builder), erlang:element(4, Builder), erlang:element(5, Builder), erlang:element(6, Builder), erlang:element(7, Builder), erlang:element(8, Builder), erlang:element(9, Builder), {some, Listener_name}, erlang:element(11, Builder), erlang:element(12, Builder)}.

-file("src\\glisten.gleam", 384).
-spec with_connection_factory_name(builder(IMK, IML), gleam@erlang@process:name(gleam@otp@factory_supervisor:message(glisten@socket:socket(), gleam@erlang@process:subject(glisten@internal@handler:message(IML))))) -> builder(IMK, IML).
-doc(false).
with_connection_factory_name(Builder, Connection_factory_name) ->
    {builder, erlang:element(2, Builder), erlang:element(3, Builder), erlang:element(4, Builder), erlang:element(5, Builder), erlang:element(6, Builder), erlang:element(7, Builder), erlang:element(8, Builder), erlang:element(9, Builder), erlang:element(10, Builder), {some, Connection_factory_name}, erlang:element(12, Builder)}.

-file("src\\glisten.gleam", 394).
-spec start(builder(any(), any()), integer()) -> {ok, gleam@otp@actor:started(gleam@otp@static_supervisor:supervisor())} | {error, gleam@otp@actor:start_error()}.
-doc(~" Start the TCP server with the given handler on the provided port").
start(Builder, Port) ->
    Listener_name = gleam@option:unwrap(erlang:element(10, Builder), gleam_erlang_ffi:new_name(~"glisten_listener")),
    Connection_supervisor = gleam@option:unwrap(erlang:element(11, Builder), gleam_erlang_ffi:new_name(~"glisten_connection_supervisor")),
    Options = begin
        _pipe = [{ip, erlang:element(2, Builder)}],
        _pipe@1 = lists:append(_pipe, case erlang:element(8, Builder) of
            true ->
                [ipv6];

            false ->
                []
        end),
        _pipe@2 = lists:append(_pipe@1, case erlang:element(9, Builder) of
            {some, Opts} ->
                [{cert_key_config, Opts}];

            _ ->
                []
        end),
        lists:append(_pipe@2, case {erlang:element(9, Builder), erlang:element(7, Builder)} of
            {{some, _}, true} ->
                [{alpn_preferred_protocols, [~"h2", ~"http/1.1"]}];

            {{some, _}, false} ->
                [{alpn_preferred_protocols, [~"http/1.1"]}];

            {none, _} ->
                []
        end)
    end,
    Transport = case erlang:element(9, Builder) of
        {some, _} ->
            ssl;

        _ ->
            tcp
    end,
    _pipe@3 = {pool, convert_loop(erlang:element(4, Builder)), erlang:element(6, Builder), Connection_supervisor, convert_on_init(erlang:element(3, Builder)), erlang:element(5, Builder), Transport, erlang:element(12, Builder)},
    glisten@internal@acceptor:start_pool(_pipe@3, Transport, Port, Options, Listener_name).

-file("src\\glisten.gleam", 443).
-spec supervised(builder(any(), any()), integer()) -> gleam@otp@supervision:child_specification(gleam@otp@static_supervisor:supervisor()).
-doc(~" Helper method for building a child specification for use in a supervision
 tree.").
supervised(Handler, Port) ->
    gleam@otp@supervision:supervisor(fun() ->
        start(Handler, Port)
    end).

