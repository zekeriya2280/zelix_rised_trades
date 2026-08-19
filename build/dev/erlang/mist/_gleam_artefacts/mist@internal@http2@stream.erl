-module(mist@internal@http2@stream).
-compile([no_auto_import, nowarn_ignored, nowarn_unused_vars, nowarn_unused_function, nowarn_nomatch, inline]).
-export([make_request/2, new/6, receive_data/2]).
-export_type([message/0, send_message/0, stream_state/0, state/0, internal_state/0]).
-moduledoc(false).

-type message() :: ready | {data, bitstring(), boolean()} | done.

-type send_message() :: {send, mist@internal@http2@frame:stream_identifier(mist@internal@http2@frame:frame()), gleam@http@response:response(mist@internal@http:response_data())}.

-type stream_state() :: open | remote_closed | local_closed | closed.

-type state() :: {state, mist@internal@http2@frame:stream_identifier(mist@internal@http2@frame:frame()), stream_state(), gleam@erlang@process:subject(message()), integer(), integer(), gleam@option:option(integer())}.

-type internal_state() :: {internal_state, gleam@erlang@process:selector(message()), gleam@erlang@process:subject(message()), boolean(), gleam@option:option(gleam@http@response:response(mist@internal@http:response_data())), bitstring()}.

-file("src\\mist\\internal\\http2\\stream.gleam", 142).
-spec make_request(list({binary(), binary()}), gleam@http@request:request(mist@internal@http:connection())) -> {ok, gleam@http@request:request(mist@internal@http:connection())} | {error, nil}.
-doc(false).
make_request(Headers, Req) ->
    case Headers of
        [] ->
            {ok, Req};

        [{~"method", Method} | Rest] ->
            _pipe = Method,
            _pipe@1 = gleam@http:parse_method(_pipe),
            _pipe@2 = gleam@result:replace_error(_pipe@1, nil),
            _pipe@3 = gleam@result:map(_pipe@2, fun(_capture) ->
                gleam@http@request:set_method(Req, _capture)
            end),
            gleam@result:'try'(_pipe@3, fun(_capture) ->
                make_request(Rest, _capture)
            end);

        [{~"scheme", Scheme} | Rest@1] ->
            _pipe@4 = Scheme,
            _pipe@5 = gleam@http:scheme_from_string(_pipe@4),
            _pipe@6 = gleam@result:replace_error(_pipe@5, nil),
            _pipe@7 = gleam@result:map(_pipe@6, fun(_capture) ->
                gleam@http@request:set_scheme(Req, _capture)
            end),
            gleam@result:'try'(_pipe@7, fun(_capture) ->
                make_request(Rest@1, _capture)
            end);

        [{~"authority", _} | Rest@2] ->
            make_request(Rest@2, Req);

        [{~"path", Path} | Rest@3] ->
            _pipe@8 = Path,
            _pipe@9 = gleam@string:split_once(_pipe@8, ~"?"),
            _pipe@10 = gleam@result:map(_pipe@9, fun(Split) ->
                gleam@pair:map_second(Split, fun(Query) ->
                    _pipe@11 = Query,
                    _pipe@12 = gleam_stdlib:parse_query(_pipe@11),
                    _pipe@13 = gleam@result:map(_pipe@12, fun(_value) ->
                        {some, _value}
                    end),
                    gleam@result:unwrap(_pipe@13, none)
                end)
            end),
            _pipe@11 = gleam@result:unwrap(_pipe@10, {Path, none}),
            fun(Tup) ->
                _pipe@12 = case erlang:element(2, Tup) of
                    {some, Query} ->
                        _pipe@13 = Req,
                        _pipe@14 = gleam@http@request:set_path(_pipe@13, erlang:element(1, Tup)),
                        gleam@http@request:set_query(_pipe@14, Query);

                    _ ->
                        gleam@http@request:set_path(Req, erlang:element(1, Tup))
                end,
                fun(_capture) ->
                    make_request(Rest@3, _capture)
                end(_pipe@12)
            end(_pipe@11);

        [{Key, Value} | Rest@4] ->
            _pipe@12 = Req,
            _pipe@13 = gleam@http@request:set_header(_pipe@12, Key, Value),
            fun(_capture) ->
                make_request(Rest@4, _capture)
            end(_pipe@13)
    end.

-file("src\\mist\\internal\\http2\\stream.gleam", 57).
-spec new(mist@internal@http2@frame:stream_identifier(mist@internal@http2@frame:frame()), fun((gleam@http@request:request(mist@internal@http:connection())) -> gleam@http@response:response(mist@internal@http:response_data())), list({binary(), binary()}), mist@internal@http:connection(), gleam@erlang@process:subject(send_message()), boolean()) -> {ok, gleam@otp@actor:started(gleam@erlang@process:subject(message()))} | {error, gleam@otp@actor:start_error()}.
-doc(false).
new(Identifier, Handler, Headers, Connection, Sender, End) ->
    _pipe = gleam@otp@actor:new_with_initialiser(1000, fun(Subject) ->
        Data_selector = begin
            _pipe@1 = gleam_erlang_ffi:new_selector(),
            gleam@erlang@process:select(_pipe@1, Subject)
        end,
        _pipe@2 = {internal_state, Data_selector, Subject, End, none, <<>>},
        _pipe@3 = gleam@otp@actor:initialised(_pipe@2),
        _pipe@4 = gleam@otp@actor:selecting(_pipe@3, Data_selector),
        _pipe@5 = gleam@otp@actor:returning(_pipe@4, Subject),
        {ok, _pipe@5}
    end),
    _pipe@1 = gleam@otp@actor:on_message(_pipe, fun(State, Msg) ->
        case {Msg, erlang:element(4, State)} of
            {ready, _} ->
                Content_length = begin
                    _pipe@2 = Headers,
                    _pipe@3 = gleam@list:key_find(_pipe@2, ~"content-length"),
                    _pipe@4 = gleam@result:'try'(_pipe@3, fun gleam_stdlib:parse_int/1),
                    gleam@result:unwrap(_pipe@4, 0)
                end,
                Conn = {connection, {stream, gleam_erlang_ffi:map_selector(erlang:element(2, State), fun(Val) ->
                    case Val of
                        {data, Bits, _} ->
                            Bits;

                        _value ->
                            erlang:error(#{
                                gleam_error => let_assert,
                                message => ~"Pattern match failed, no pattern matched the value.",
                                file => ~"src\\mist\\internal\\http2\\stream.gleam",
                                module => ~"mist/internal/http2/stream",
                                function => ~"new",
                                line => 88,
                                value => _value,
                                start => 2215,
                                'end' => 2246,
                                pattern_start => 2226,
                                pattern_end => 2240
                            })
                    end
                end), <<>>, Content_length, 0}, erlang:element(3, Connection), erlang:element(4, Connection), erlang:element(5, Connection)},
                Result = begin
                    _pipe@5 = gleam@http@request:new(),
                    _pipe@6 = gleam@http@request:set_body(_pipe@5, Conn),
                    fun(_capture) ->
                        make_request(Headers, _capture)
                    end(_pipe@6)
                end,
                case Result of
                    {ok, Value} ->
                        Resp = Handler(Value),
                        gleam@erlang@process:send(erlang:element(3, State), done),
                        gleam@otp@actor:continue({internal_state, erlang:element(2, State), erlang:element(3, State), erlang:element(4, State), {some, Resp}, erlang:element(6, State)});

                    {error, Err} ->
                        gleam@otp@actor:stop_abnormal(<<"Failed to respond to request: "/utf8, (gleam@string:inspect(Err))/binary>>)
                end;

            {done, true} ->
                case erlang:element(5, State) of
                    {some, Resp@1} ->
                        gleam@erlang@process:send(Sender, {send, Identifier, Resp@1}),
                        gleam@otp@actor:continue(State);

                    _value@1 ->
                        erlang:error(#{
                            gleam_error => let_assert,
                            message => ~"Pattern match failed, no pattern matched the value.",
                            file => ~"src\\mist\\internal\\http2\\stream.gleam",
                            module => ~"mist/internal/http2/stream",
                            function => ~"new",
                            line => 115,
                            value => _value@1,
                            start => 2947,
                            'end' => 2993,
                            pattern_start => 2958,
                            pattern_end => 2968
                        })
                end;

            {{data, Bits, true}, _} ->
                gleam@erlang@process:send(erlang:element(3, State), done),
                gleam@otp@actor:continue({internal_state, erlang:element(2, State), erlang:element(3, State), true, erlang:element(5, State), <<(erlang:element(6, State))/bitstring, Bits/bitstring>>});

            {{data, Bits@1, _}, _} ->
                gleam@otp@actor:continue({internal_state, erlang:element(2, State), erlang:element(3, State), erlang:element(4, State), erlang:element(5, State), <<(erlang:element(6, State))/bitstring, Bits@1/bitstring>>});

            {_, _} ->
                gleam@otp@actor:continue(State)
        end
    end),
    gleam@otp@actor:start(_pipe@1).

-file("src\\mist\\internal\\http2\\stream.gleam", 194).
-spec receive_data(state(), integer()) -> {state(), integer()}.
-doc(false).
receive_data(State, Size) ->
    {New_window_size, Increment} = mist@internal@http2@flow_control:compute_receive_window(erlang:element(5, State), Size),
    New_state = {state, erlang:element(2, State), erlang:element(3, State), erlang:element(4, State), New_window_size, erlang:element(6, State), gleam@option:map(erlang:element(7, State), fun(Val) ->
        Val - Size
    end)},
    {New_state, Increment}.

