-module(mist@internal@websocket).
-compile([no_auto_import, nowarn_ignored, nowarn_unused_vars, nowarn_unused_function, nowarn_nomatch, inline]).
-export([set_active/2, initialize_connection/6]).
-export_type([valid_message/1, websocket_message/1, websocket_connection/0, handler_message/1, websocket_state/1]).
-moduledoc(false).

-type valid_message(LVA) :: {socket_message, bitstring()} | socket_closed_message | {user_message, LVA}.

-type websocket_message(LVB) :: {valid, valid_message(LVB)} | invalid.

-type websocket_connection() :: {websocket_connection, glisten@socket:socket(), glisten@transport:transport(), gleam@option:option(gramps@websocket@compression:context())}.

-type handler_message(LVC) :: {internal, gramps@websocket:frame()} | {user, LVC}.

-type websocket_state(LVD) :: {websocket_state, bitstring(), LVD, gleam@option:option(gramps@websocket@compression:compression())}.

-file("src\\mist\\internal\\websocket.gleam", 54).
-spec message_selector() -> gleam@erlang@process:selector(websocket_message(any())).
-doc(false).
message_selector() ->
    _pipe = gleam_erlang_ffi:new_selector(),
    _pipe@1 = gleam@erlang@process:select_record(_pipe, erlang:binary_to_atom(~"tcp"), 2, fun(Record) ->
        _pipe@2 = begin
            gleam@dynamic@decode:field(2, {decoder, fun gleam@dynamic@decode:decode_bit_array/1}, fun(Data) ->
                gleam@dynamic@decode:success({socket_message, Data})
            end)
        end,
        _pipe@3 = fun(_capture) ->
            gleam@dynamic@decode:run(Record, _capture)
        end(_pipe@2),
        _pipe@4 = gleam@result:replace_error(_pipe@3, nil),
        _pipe@5 = gleam@result:map(_pipe@4, fun(_value) ->
            {valid, _value}
        end),
        gleam@result:unwrap(_pipe@5, invalid)
    end),
    _pipe@2 = gleam@erlang@process:select_record(_pipe@1, erlang:binary_to_atom(~"ssl"), 2, fun(Record) ->
        _pipe@3 = begin
            gleam@dynamic@decode:field(2, {decoder, fun gleam@dynamic@decode:decode_bit_array/1}, fun(Data) ->
                gleam@dynamic@decode:success({socket_message, Data})
            end)
        end,
        _pipe@4 = fun(_capture) ->
            gleam@dynamic@decode:run(Record, _capture)
        end(_pipe@3),
        _pipe@5 = gleam@result:replace_error(_pipe@4, nil),
        _pipe@6 = gleam@result:map(_pipe@5, fun(_value@1) ->
            {valid, _value@1}
        end),
        gleam@result:unwrap(_pipe@6, invalid)
    end),
    _pipe@3 = gleam@erlang@process:select_record(_pipe@2, erlang:binary_to_atom(~"ssl_closed"), 1, fun(_) ->
        {valid, socket_closed_message}
    end),
    gleam@erlang@process:select_record(_pipe@3, erlang:binary_to_atom(~"tcp_closed"), 1, fun(_) ->
        {valid, socket_closed_message}
    end).

-file("src\\mist\\internal\\websocket.gleam", 393).
-spec map_user_selector(gleam@option:option(gleam@erlang@process:selector(LWH))) -> gleam@option:option(gleam@erlang@process:selector(websocket_message(LWH))).
-doc(false).
map_user_selector(Selector) ->
    gleam@option:map(Selector, fun(_capture) ->
        gleam_erlang_ffi:map_selector(_capture, fun(Msg) ->
            {valid, {user_message, Msg}}
        end)
    end).

-file("src\\mist\\internal\\websocket.gleam", 386).
-spec set_active(glisten@transport:transport(), glisten@socket:socket()) -> nil.
-doc(false).
set_active(Transport, Socket) ->
    case glisten@transport:set_opts(Transport, Socket, [{active_mode, once}]) of
        {ok, _} ->
            nil;

        _value ->
            erlang:error(#{
                gleam_error => let_assert,
                message => ~"Pattern match failed, no pattern matched the value.",
                file => ~"src\\mist\\internal\\websocket.gleam",
                module => ~"mist/internal/websocket",
                function => ~"set_active",
                line => 387,
                value => _value,
                start => 12009,
                'end' => 12105,
                pattern_start => 12020,
                pattern_end => 12025
            })
    end.

-file("src\\mist\\internal\\websocket.gleam", 291).
-spec apply_frames(list(gramps@websocket:frame()), fun((LVX, handler_message(LVY), websocket_connection()) -> mist@internal@next:next(LVX, LVY)), websocket_connection(), mist@internal@next:next(LVX, websocket_message(LVY)), fun((LVX) -> nil)) -> mist@internal@next:next(LVX, websocket_message(LVY)).
-doc(false).
apply_frames(Frames, Handler, Connection, Next, On_close) ->
    case {Frames, Next} of
        {_, {abnormal_stop, Reason}} ->
            {abnormal_stop, Reason};

        {_, normal_stop} ->
            normal_stop;

        {[], Next@1} ->
            set_active(erlang:element(3, Connection), erlang:element(2, Connection)),
            Next@1;

        {[{control, {close_frame, Reason@1}} | _], {continue, State, _}} ->
            _ = glisten@transport:send(erlang:element(3, Connection), erlang:element(2, Connection), gramps@websocket:encode_close_frame(Reason@1, none)),
            On_close(State),
            normal_stop;

        {[{control, {ping_frame, Payload}} | Rest], {continue, State@1, _} = Continue} ->
            _pipe = glisten@transport:send(erlang:element(3, Connection), erlang:element(2, Connection), gramps@websocket:encode_pong_frame(Payload, none)),
            _pipe@1 = gleam@result:map(_pipe, fun(_) ->
                set_active(erlang:element(3, Connection), erlang:element(2, Connection)),
                apply_frames(Rest, Handler, Connection, Continue, On_close)
            end),
            gleam@result:lazy_unwrap(_pipe@1, fun() ->
                On_close(State@1),
                {abnormal_stop, ~"Failed to send pong frame"}
            end);

        {[Frame | Rest@1], {continue, State@2, Prev_selector}} ->
            case exception_ffi:rescue(fun() ->
                Handler(State@2, {internal, Frame}, Connection)
            end) of
                {ok, {continue, State@3, Selector}} ->
                    Next_selector = begin
                        _pipe@2 = Selector,
                        _pipe@3 = map_user_selector(_pipe@2),
                        _pipe@4 = gleam@option:'or'(_pipe@3, Prev_selector),
                        gleam@option:map(_pipe@4, fun(With_user) ->
                            gleam_erlang_ffi:merge_selector(message_selector(), With_user)
                        end)
                    end,
                    apply_frames(Rest@1, Handler, Connection, {continue, State@3, Next_selector}, On_close);

                {ok, {abnormal_stop, Reason@2}} ->
                    _ = glisten@transport:send(erlang:element(3, Connection), erlang:element(2, Connection), gramps@websocket:encode_close_frame({custom_close_reason, 4000, gleam_stdlib:identity(Reason@2)}, none)),
                    On_close(State@2),
                    {abnormal_stop, Reason@2};

                {ok, normal_stop} ->
                    _ = glisten@transport:send(erlang:element(3, Connection), erlang:element(2, Connection), gramps@websocket:encode_close_frame({normal, <<>>}, none)),
                    On_close(State@2),
                    normal_stop;

                {error, _} ->
                    logging:log(error, ~"Caught error in websocket handler"),
                    On_close(State@2),
                    {abnormal_stop, ~"Crash in user websocket handler"}
            end
    end.

-file("src\\mist\\internal\\websocket.gleam", 84).
-spec initialize_connection(fun((websocket_connection()) -> {LVM, gleam@option:option(gleam@erlang@process:selector(LVN))}), fun((LVM) -> nil), fun((LVM, handler_message(LVN), websocket_connection()) -> mist@internal@next:next(LVM, LVN)), glisten@socket:socket(), glisten@transport:transport(), list(binary())) -> {ok, gleam@otp@actor:started(gleam@erlang@process:pid_())} | {error, gleam@otp@actor:start_error()}.
-doc(false).
initialize_connection(On_init, On_close, Handler, Socket, Transport, Extensions) ->
    Takeovers = gramps@websocket:get_context_takeovers(Extensions),
    _pipe = gleam@otp@actor:new_with_initialiser(500, fun(Subject) ->
        Compression = case gramps@websocket:has_deflate(Extensions) of
            true ->
                {some, gramps@websocket@compression:init(Takeovers)};

            false ->
                none
        end,
        Connection = {websocket_connection, Socket, Transport, gleam@option:map(Compression, fun(Compression@1) ->
            erlang:element(3, Compression@1)
        end)},
        {Initial_state, User_selector} = On_init(Connection),
        Selector = case User_selector of
            {some, User_selector@1} ->
                _pipe@1 = User_selector@1,
                _pipe@2 = gleam_erlang_ffi:map_selector(_pipe@1, fun(_value) ->
                    {user_message, _value}
                end),
                _pipe@3 = gleam_erlang_ffi:map_selector(_pipe@2, fun(_value@1) ->
                    {valid, _value@1}
                end),
                gleam_erlang_ffi:merge_selector(_pipe@3, message_selector());

            _ ->
                message_selector()
        end,
        _pipe@4 = {websocket_state, <<>>, Initial_state, Compression},
        _pipe@5 = gleam@otp@actor:initialised(_pipe@4),
        _pipe@6 = gleam@otp@actor:selecting(_pipe@5, Selector),
        _pipe@7 = gleam@otp@actor:returning(_pipe@6, Subject),
        {ok, _pipe@7}
    end),
    _pipe@1 = gleam@otp@actor:on_message(_pipe, fun(State, Msg) ->
        Connection = {websocket_connection, Socket, Transport, gleam@option:map(erlang:element(4, State), fun(Compression) ->
            erlang:element(3, Compression)
        end)},
        case Msg of
            {valid, {socket_message, Data}} ->
                {Frames, Rest} = gramps@websocket:decode_many_frames(<<(erlang:element(2, State))/bitstring, Data/bitstring>>, gleam@option:map(erlang:element(4, State), fun(Compression) ->
                    erlang:element(2, Compression)
                end), []),
                _pipe@2 = Frames,
                _pipe@3 = gramps@websocket:aggregate_frames(_pipe@2, none, []),
                _pipe@4 = gleam@result:map(_pipe@3, fun(Frames@1) ->
                    Next = apply_frames(Frames@1, Handler, Connection, {continue, erlang:element(3, State), none}, On_close),
                    case Next of
                        {continue, User_state, Selector} ->
                            Next@1 = gleam@otp@actor:continue({websocket_state, Rest, User_state, erlang:element(4, State)}),
                            case Selector of
                                {some, Selector@1} ->
                                    gleam@otp@actor:with_selector(Next@1, Selector@1);

                                _ ->
                                    Next@1
                            end;

                        normal_stop ->
                            _ = gleam@option:map(erlang:element(4, State), fun(Contexts) ->
                                gramps@websocket@compression:close(erlang:element(3, Contexts)),
                                gramps@websocket@compression:close(erlang:element(2, Contexts))
                            end),
                            gleam@otp@actor:stop();

                        {abnormal_stop, Reason} ->
                            _ = gleam@option:map(erlang:element(4, State), fun(Contexts) ->
                                gramps@websocket@compression:close(erlang:element(3, Contexts)),
                                gramps@websocket@compression:close(erlang:element(2, Contexts))
                            end),
                            gleam@otp@actor:stop_abnormal(Reason)
                    end
                end),
                gleam@result:lazy_unwrap(_pipe@4, fun() ->
                    logging:log(error, ~"Received a malformed WebSocket frame"),
                    On_close(erlang:element(3, State)),
                    _ = gleam@option:map(erlang:element(4, State), fun(Contexts) ->
                        gramps@websocket@compression:close(erlang:element(3, Contexts)),
                        gramps@websocket@compression:close(erlang:element(2, Contexts))
                    end),
                    gleam@otp@actor:stop_abnormal(~"WebSocket received a malformed message")
                end);

            {valid, {user_message, Msg@1}} ->
                _pipe@5 = exception_ffi:rescue(fun() ->
                    Handler(erlang:element(3, State), {user, Msg@1}, Connection)
                end),
                _pipe@6 = gleam@result:map(_pipe@5, fun(Cont) ->
                    case Cont of
                        {continue, User_state, Selector} ->
                            Selector@1 = begin
                                _pipe@7 = Selector,
                                _pipe@8 = map_user_selector(_pipe@7),
                                gleam@option:map(_pipe@8, fun(With_user) ->
                                    gleam_erlang_ffi:merge_selector(message_selector(), With_user)
                                end)
                            end,
                            Next = gleam@otp@actor:continue({websocket_state, erlang:element(2, State), User_state, erlang:element(4, State)}),
                            case Selector@1 of
                                {some, Selector@2} ->
                                    gleam@otp@actor:with_selector(Next, Selector@2);

                                _ ->
                                    Next
                            end;

                        normal_stop ->
                            _ = glisten@transport:send(erlang:element(3, Connection), erlang:element(2, Connection), gramps@websocket:encode_close_frame({normal, <<>>}, none)),
                            _ = gleam@option:map(erlang:element(4, State), fun(Contexts) ->
                                gramps@websocket@compression:close(erlang:element(3, Contexts)),
                                gramps@websocket@compression:close(erlang:element(2, Contexts))
                            end),
                            On_close(erlang:element(3, State)),
                            gleam@otp@actor:stop();

                        {abnormal_stop, Reason} ->
                            _ = glisten@transport:send(erlang:element(3, Connection), erlang:element(2, Connection), gramps@websocket:encode_close_frame({custom_close_reason, 4000, gleam_stdlib:identity(Reason)}, none)),
                            _ = gleam@option:map(erlang:element(4, State), fun(Contexts) ->
                                gramps@websocket@compression:close(erlang:element(3, Contexts)),
                                gramps@websocket@compression:close(erlang:element(2, Contexts))
                            end),
                            On_close(erlang:element(3, State)),
                            gleam@otp@actor:stop_abnormal(Reason)
                    end
                end),
                _pipe@7 = gleam@result:map_error(_pipe@6, fun(_) ->
                    logging:log(error, ~"Caught error in websocket handler")
                end),
                gleam@result:lazy_unwrap(_pipe@7, fun() ->
                    _ = gleam@option:map(erlang:element(4, State), fun(Contexts) ->
                        gramps@websocket@compression:close(erlang:element(3, Contexts)),
                        gramps@websocket@compression:close(erlang:element(2, Contexts))
                    end),
                    On_close(erlang:element(3, State)),
                    gleam@otp@actor:stop_abnormal(~"Crash in user websocket handler")
                end);

            {valid, socket_closed_message} ->
                _ = gleam@option:map(erlang:element(4, State), fun(Contexts) ->
                    gramps@websocket@compression:close(erlang:element(3, Contexts)),
                    gramps@websocket@compression:close(erlang:element(2, Contexts))
                end),
                On_close(erlang:element(3, State)),
                gleam@otp@actor:stop();

            invalid ->
                logging:log(error, ~"Received a malformed WebSocket frame"),
                _ = gleam@option:map(erlang:element(4, State), fun(Contexts) ->
                    gramps@websocket@compression:close(erlang:element(3, Contexts)),
                    gramps@websocket@compression:close(erlang:element(2, Contexts))
                end),
                On_close(erlang:element(3, State)),
                gleam@otp@actor:stop_abnormal(~"WebSocket received a malformed message")
        end
    end),
    _pipe@2 = gleam@otp@actor:start(_pipe@1),
    gleam@result:map(_pipe@2, fun(Subj) ->
        case gleam@erlang@process:subject_owner(erlang:element(3, Subj)) of
            {ok, Websocket_pid} ->
                {started, Websocket_pid, Websocket_pid};

            _value@2 ->
                erlang:error(#{
                    gleam_error => let_assert,
                    message => ~"Pattern match failed, no pattern matched the value.",
                    file => ~"src\\mist\\internal\\websocket.gleam",
                    module => ~"mist/internal/websocket",
                    function => ~"initialize_connection",
                    line => 286,
                    value => _value@2,
                    start => 9039,
                    'end' => 9102,
                    pattern_start => 9050,
                    pattern_end => 9067
                })
        end
    end).

