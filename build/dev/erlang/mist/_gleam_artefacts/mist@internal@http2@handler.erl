-module(mist@internal@http2@handler).
-compile([no_auto_import, nowarn_ignored, nowarn_unused_vars, nowarn_unused_function, nowarn_nomatch, inline]).
-export([send_hpack_context/2, receive_hpack_context/2, append_data/2, upgrade/3, call/3]).
-export_type([pending_send/0, state/0]).
-moduledoc(false).

-type pending_send() :: pending_send.

-type state() :: {state, gleam@option:option(mist@internal@http2@frame:frame()), mist@internal@buffer:buffer(), list(pending_send()), mist@internal@http2:hpack_context(), gleam@erlang@process:subject(mist@internal@http2@stream:send_message()), mist@internal@http2:hpack_context(), integer(), integer(), mist@internal@http2:http2_settings(), gleam@dict:dict(mist@internal@http2@frame:stream_identifier(mist@internal@http2@frame:frame()), mist@internal@http2@stream:state())}.

-file("src\\mist\\internal\\http2\\handler.gleam", 38).
-spec send_hpack_context(state(), mist@internal@http2:hpack_context()) -> state().
-doc(false).
send_hpack_context(State, Context) ->
    {state, erlang:element(2, State), erlang:element(3, State), erlang:element(4, State), erlang:element(5, State), erlang:element(6, State), Context, erlang:element(8, State), erlang:element(9, State), erlang:element(10, State), erlang:element(11, State)}.

-file("src\\mist\\internal\\http2\\handler.gleam", 42).
-spec receive_hpack_context(state(), mist@internal@http2:hpack_context()) -> state().
-doc(false).
receive_hpack_context(State, Context) ->
    {state, erlang:element(2, State), erlang:element(3, State), erlang:element(4, State), Context, erlang:element(6, State), erlang:element(7, State), erlang:element(8, State), erlang:element(9, State), erlang:element(10, State), erlang:element(11, State)}.

-file("src\\mist\\internal\\http2\\handler.gleam", 46).
-spec append_data(state(), bitstring()) -> state().
-doc(false).
append_data(State, Data) ->
    {state, erlang:element(2, State), mist@internal@buffer:append(erlang:element(3, State), Data), erlang:element(4, State), erlang:element(5, State), erlang:element(6, State), erlang:element(7, State), erlang:element(8, State), erlang:element(9, State), erlang:element(10, State), erlang:element(11, State)}.

-file("src\\mist\\internal\\http2\\handler.gleam", 50).
-spec upgrade(bitstring(), mist@internal@http:connection(), gleam@erlang@process:subject(mist@internal@http2@stream:send_message())) -> {ok, state()} | {error, binary()}.
-doc(false).
upgrade(Data, Conn, Self) ->
    Initial_settings = mist@internal@http2:default_settings(),
    Settings_frame = {settings, false, []},
    Sent = begin
        _pipe = mist@internal@http2:send_frame(Settings_frame, erlang:element(3, Conn), erlang:element(4, Conn)),
        gleam@result:replace_error(_pipe, ~"Failed to send settings frame")
    end,
    gleam@result:map(Sent, fun(_) ->
        {state, none, mist@internal@buffer:new(Data), [], hpack:new_context(erlang:element(2, Initial_settings)), Self, hpack:new_context(erlang:element(2, Initial_settings)), 65535, 65535, Initial_settings, maps:new()}
    end).

-file("src\\mist\\internal\\http2\\handler.gleam", 106).
-spec handle_frame(mist@internal@http2@frame:frame(), state(), mist@internal@http:connection(), fun((gleam@http@request:request(mist@internal@http:connection())) -> gleam@http@response:response(mist@internal@http:response_data()))) -> {ok, state()} | {error, binary()}.
-doc(false).
handle_frame(Frame, State, Conn, Handler) ->
    case {erlang:element(2, State), Frame} of
        {{some, {header, {continued, Existing}, End_stream, Id1, Priority}}, {continuation, {complete, Data}, Id2}} when Id1 =:= Id2 ->
            Complete_frame = {header, {complete, <<Existing/bitstring, Data/bitstring>>}, End_stream, Id1, Priority},
            handle_frame(Complete_frame, {state, none, erlang:element(3, State), erlang:element(4, State), erlang:element(5, State), erlang:element(6, State), erlang:element(7, State), erlang:element(8, State), erlang:element(9, State), erlang:element(10, State), erlang:element(11, State)}, Conn, Handler);

        {{some, {header, {continued, Existing@1}, End_stream@1, Id1@1, Priority@1}}, {continuation, {continued, Data@1}, Id2@1}} when Id1@1 =:= Id2@1 ->
            Next = {header, {continued, <<Existing@1/bitstring, Data@1/bitstring>>}, End_stream@1, Id1@1, Priority@1},
            {ok, {state, {some, Next}, erlang:element(3, State), erlang:element(4, State), erlang:element(5, State), erlang:element(6, State), erlang:element(7, State), erlang:element(8, State), erlang:element(9, State), erlang:element(10, State), erlang:element(11, State)}};

        {none, {window_update, Amount, Identifier}} ->
            case mist@internal@http2@frame:get_stream_identifier(Identifier) of
                0 ->
                    {ok, {state, erlang:element(2, State), erlang:element(3, State), erlang:element(4, State), erlang:element(5, State), erlang:element(6, State), erlang:element(7, State), erlang:element(8, State), erlang:element(9, State), begin
                        _record = erlang:element(10, State),
                        {http2_settings, erlang:element(2, _record), erlang:element(3, _record), erlang:element(4, _record), Amount, erlang:element(6, _record), erlang:element(7, _record)}
                    end, erlang:element(11, State)}};

                _ ->
                    _pipe = erlang:element(11, State),
                    _pipe@1 = gleam_stdlib:map_get(_pipe, Identifier),
                    _pipe@2 = gleam@result:replace_error(_pipe@1, ~"Window update for non-existent stream"),
                    gleam@result:'try'(_pipe@2, fun(Stream) ->
                        case mist@internal@http2@flow_control:update_send_window(erlang:element(6, Stream), Amount) of
                            {ok, Update} ->
                                New_stream = {state, erlang:element(2, Stream), erlang:element(3, Stream), erlang:element(4, Stream), erlang:element(5, Stream), Update, erlang:element(7, Stream)},
                                {ok, {state, erlang:element(2, State), erlang:element(3, State), erlang:element(4, State), erlang:element(5, State), erlang:element(6, State), erlang:element(7, State), erlang:element(8, State), erlang:element(9, State), erlang:element(10, State), gleam@dict:insert(erlang:element(11, State), Identifier, New_stream)}};

                            _ ->
                                {error, ~"Failed to update send window"}
                        end
                    end)
            end;

        {none, {header, {complete, Data@2}, End_stream@2, Identifier@1, _}} ->
            Conn@1 = {connection, {initial, <<>>}, erlang:element(3, Conn), erlang:element(4, Conn), erlang:element(5, Conn)},
            case mist_ffi:hpack_decode(erlang:element(5, State), Data@2) of
                {ok, {Headers, Context}} ->
                    Pending_content_length = begin
                        _pipe@3 = Headers,
                        _pipe@4 = gleam@list:key_find(_pipe@3, ~"content-length"),
                        _pipe@5 = gleam@result:'try'(_pipe@4, fun gleam_stdlib:parse_int/1),
                        gleam@option:from_result(_pipe@5)
                    end,
                    case mist@internal@http2@stream:new(Identifier@1, Handler, Headers, Conn@1, erlang:element(6, State), End_stream@2) of
                        {ok, New_stream} ->
                            gleam@erlang@process:send(erlang:element(3, New_stream), ready),
                            Stream_state = {state, Identifier@1, open, erlang:element(3, New_stream), erlang:element(5, erlang:element(10, State)), erlang:element(5, erlang:element(10, State)), Pending_content_length},
                            Streams = gleam@dict:insert(erlang:element(11, State), Identifier@1, Stream_state),
                            {ok, {state, erlang:element(2, State), erlang:element(3, State), erlang:element(4, State), Context, erlang:element(6, State), erlang:element(7, State), erlang:element(8, State), erlang:element(9, State), erlang:element(10, State), Streams}};

                        _value ->
                            erlang:error(#{
                                gleam_error => let_assert,
                                message => ~"Pattern match failed, no pattern matched the value.",
                                file => ~"src\\mist\\internal\\http2\\handler.gleam",
                                module => ~"mist/internal/http2/handler",
                                function => ~"handle_frame",
                                line => 203,
                                value => _value,
                                start => 5743,
                                'end' => 5996,
                                pattern_start => 5754,
                                pattern_end => 5768
                            })
                    end;

                _value@1 ->
                    erlang:error(#{
                        gleam_error => let_assert,
                        message => ~"Pattern match failed, no pattern matched the value.",
                        file => ~"src\\mist\\internal\\http2\\handler.gleam",
                        module => ~"mist/internal/http2/handler",
                        function => ~"handle_frame",
                        line => 194,
                        value => _value@1,
                        start => 5479,
                        'end' => 5577,
                        pattern_start => 5490,
                        pattern_end => 5513
                    })
            end;

        {none, {data, Data@3, End_stream@3, Identifier@2}} ->
            Data_size = erlang:byte_size(Data@3),
            {Conn_receive_window_size, Conn_window_increment} = mist@internal@http2@flow_control:compute_receive_window(erlang:element(9, State), Data_size),
            _pipe@6 = erlang:element(11, State),
            _pipe@7 = gleam_stdlib:map_get(_pipe@6, Identifier@2),
            _pipe@8 = gleam@result:map(_pipe@7, fun(_capture) ->
                mist@internal@http2@stream:receive_data(_capture, Data_size)
            end),
            _pipe@9 = gleam@result:replace_error(_pipe@8, ~"Stream failed to receive data"),
            gleam@result:map(_pipe@9, fun(Update) ->
                {New_stream@1, Increment} = Update,
                _ = case Conn_window_increment > 0 of
                    true ->
                        mist@internal@http2:send_frame({window_update, Conn_window_increment, mist@internal@http2@frame:stream_identifier(0)}, erlang:element(3, Conn), erlang:element(4, Conn));

                    false ->
                        {ok, nil}
                end,
                _ = case Increment > 0 of
                    true ->
                        mist@internal@http2:send_frame({window_update, Increment, Identifier@2}, erlang:element(3, Conn), erlang:element(4, Conn));

                    false ->
                        {ok, nil}
                end,
                gleam@erlang@process:send(erlang:element(4, New_stream@1), {data, Data@3, End_stream@3}),
                {state, erlang:element(2, State), erlang:element(3, State), erlang:element(4, State), erlang:element(5, State), erlang:element(6, State), erlang:element(7, State), erlang:element(8, State), Conn_receive_window_size, erlang:element(10, State), gleam@dict:insert(erlang:element(11, State), Identifier@2, New_stream@1)}
            end);

        {none, {priority, _, _, _, _}} ->
            {ok, State};

        {none, {settings, true, _}} ->
            {ok, State};

        {_, {settings, _, _}} ->
            _pipe@10 = mist@internal@http2:send_frame(mist@internal@http2@frame:settings_ack(), erlang:element(3, Conn), erlang:element(4, Conn)),
            _pipe@11 = gleam@result:replace(_pipe@10, State),
            gleam@result:replace_error(_pipe@11, ~"Failed to respond to settings ACK");

        {none, {go_away, _, _, _}} ->
            logging:log(debug, ~"byteeee~~"),
            {error, ~"Going away..."};

        {_, Frame@1} ->
            logging:log(debug, <<"Ignoring frame: "/utf8, (gleam@string:inspect(Frame@1))/binary>>),
            {ok, State}
    end.

-file("src\\mist\\internal\\http2\\handler.gleam", 81).
-spec call(state(), mist@internal@http:connection(), fun((gleam@http@request:request(mist@internal@http:connection())) -> gleam@http@response:response(mist@internal@http:response_data()))) -> {ok, state()} | {error, {ok, nil} | {error, binary()}}.
-doc(false).
call(State, Conn, Handler) ->
    case mist@internal@http2@frame:decode(erlang:element(3, erlang:element(3, State))) of
        {ok, {Frame, Rest}} ->
            New_state = {state, erlang:element(2, State), mist@internal@buffer:new(Rest), erlang:element(4, State), erlang:element(5, State), erlang:element(6, State), erlang:element(7, State), erlang:element(8, State), erlang:element(9, State), erlang:element(10, State), erlang:element(11, State)},
            case handle_frame(Frame, New_state, Conn, Handler) of
                {ok, Updated} ->
                    call(Updated, Conn, Handler);

                {error, Reason} ->
                    {error, {error, Reason}}
            end;

        {error, no_error} ->
            {ok, State};

        {error, _} ->
            {ok, State}
    end.

