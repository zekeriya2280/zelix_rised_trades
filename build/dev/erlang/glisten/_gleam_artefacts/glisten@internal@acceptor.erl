-module(glisten@internal@acceptor).
-compile([no_auto_import, nowarn_ignored, nowarn_unused_vars, nowarn_unused_function, nowarn_nomatch, inline]).
-export([start/3, start_pool/5]).
-export_type([acceptor_message/0, acceptor_error/0, acceptor_state/0, pool/2]).
-moduledoc(false).

-type acceptor_message() :: {accept_connection, glisten@socket:listen_socket()}.

-type acceptor_error() :: {accept_error, glisten@socket:socket_reason()} | {handler_error, gleam@otp@actor:start_error()} | {control_error, gleam@erlang@atom:atom_()}.

-type acceptor_state() :: {acceptor_state, gleam@erlang@process:subject(acceptor_message()), gleam@option:option(glisten@socket:socket()), glisten@transport:transport()}.

-type pool(IAX, IAY) :: {pool, fun((IAX, glisten@internal@handler:loop_message(IAY), glisten@internal@handler:connection(IAY)) -> glisten@internal@handler:next(IAX, glisten@internal@handler:loop_message(IAY))), integer(), gleam@erlang@process:name(gleam@otp@factory_supervisor:message(glisten@socket:socket(), gleam@erlang@process:subject(glisten@internal@handler:message(IAY)))), fun((glisten@internal@handler:connection(IAY)) -> {IAX, gleam@option:option(gleam@erlang@process:selector(IAY))}), gleam@option:option(fun((IAX) -> nil)), glisten@transport:transport(), glisten@socket@options:active_state()}.

-file("src\\glisten\\internal\\acceptor.gleam", 39).
-spec start(pool(any(), IBA), gleam@erlang@process:name(glisten@internal@listener:message()), gleam@erlang@process:name(gleam@otp@factory_supervisor:message(glisten@socket:socket(), gleam@erlang@process:subject(glisten@internal@handler:message(IBA))))) -> {ok, gleam@otp@actor:started(gleam@erlang@process:subject(acceptor_message()))} | {error, gleam@otp@actor:start_error()}.
-doc(false).
start(Pool, Listener_name, Connection_supervisor) ->
    _pipe = gleam@otp@actor:new_with_initialiser(1000, fun(Subject) ->
        Listener = gleam@erlang@process:named_subject(Listener_name),
        State = gleam@erlang@process:call(Listener, 750, fun(_value) ->
            {info, _value}
        end),
        gleam@erlang@process:send(Subject, {accept_connection, erlang:element(2, State)}),
        _pipe@1 = {acceptor_state, Subject, none, erlang:element(7, Pool)},
        _pipe@2 = gleam@otp@actor:initialised(_pipe@1),
        _pipe@3 = gleam@otp@actor:returning(_pipe@2, Subject),
        _pipe@4 = gleam@otp@actor:selecting(_pipe@3, begin
            _pipe@5 = gleam_erlang_ffi:new_selector(),
            gleam@erlang@process:select(_pipe@5, Subject)
        end),
        {ok, _pipe@4}
    end),
    _pipe@1 = gleam@otp@actor:on_message(_pipe, fun(State, Msg) ->
        {acceptor_state, Sender, _, _} = State,
        case Msg of
            {accept_connection, Listener} ->
                Res = begin
                    gleam@result:'try'(begin
                        _pipe@2 = glisten@transport:accept(erlang:element(4, State), Listener),
                        gleam@result:map_error(_pipe@2, fun(_value@1) ->
                            {accept_error, _value@1}
                        end)
                    end, fun(Sock) ->
                        Connection_factory = gleam@otp@factory_supervisor:get_by_name(Connection_supervisor),
                        case gleam@otp@factory_supervisor:start_child(Connection_factory, Sock) of
                            {ok, Start} ->
                                _pipe@3 = glisten@transport:controlling_process(erlang:element(4, State), Sock, erlang:element(2, Start)),
                                _pipe@4 = gleam@result:map_error(_pipe@3, fun(_value@2) ->
                                    {control_error, _value@2}
                                end),
                                gleam@result:map(_pipe@4, fun(_) ->
                                    gleam@erlang@process:send(erlang:element(3, Start), {internal, ready})
                                end);

                            {error, Reason} ->
                                {error, {handler_error, Reason}}
                        end
                    end)
                end,
                case Res of
                    {error, Reason} ->
                        Msg@1 = case Reason of
                            {accept_error, Reason@1} ->
                                <<"acceptor failed: "/utf8, (glisten@socket:reason_to_string(Reason@1))/binary>>;

                            {handler_error, init_timeout} ->
                                ~"init timed out";

                            {handler_error, {init_failed, Reason@2}} ->
                                <<"init failed: "/utf8, Reason@2/binary>>;

                            {handler_error, {init_exited, normal}} ->
                                ~"init exited normally";

                            {handler_error, {init_exited, killed}} ->
                                ~"init killed";

                            {handler_error, {init_exited, {abnormal, _}}} ->
                                ~"init exited abnormally";

                            {control_error, Reason@3} ->
                                <<"could not control socket: "/utf8, (erlang:atom_to_binary(Reason@3))/binary>>
                        end,
                        logging:log(error, <<"Failed to accept/start handler: "/utf8, Msg@1/binary>>),
                        gleam@otp@actor:stop_abnormal(~"Failed to accept/start handler");

                    _ ->
                        gleam@otp@actor:send(Sender, {accept_connection, Listener}),
                        gleam@otp@actor:continue(State)
                end
        end
    end),
    gleam@otp@actor:start(_pipe@1).

-file("src\\glisten\\internal\\acceptor.gleam", 133).
-spec start_pool(pool(any(), any()), glisten@transport:transport(), integer(), list(glisten@socket@options:tcp_option()), gleam@erlang@process:name(glisten@internal@listener:message())) -> {ok, gleam@otp@actor:started(gleam@otp@static_supervisor:supervisor())} | {error, gleam@otp@actor:start_error()}.
-doc(false).
start_pool(Pool, Transport, Port, Options, Listener_name) ->
    _pipe = gleam@otp@static_supervisor:new(one_for_one),
    _pipe@1 = gleam@otp@static_supervisor:add(_pipe, gleam@otp@supervision:worker(fun() ->
        glisten@internal@listener:start(Port, Transport, Options, Listener_name)
    end)),
    _pipe@2 = gleam@otp@static_supervisor:add(_pipe@1, gleam@otp@supervision:supervisor(fun() ->
        _pipe@3 = gleam@otp@static_supervisor:new(one_for_one),
        _pipe@4 = fun(_capture) ->
            gleam@int:range(0, erlang:element(3, Pool), _capture, fun(Sup, _) ->
                gleam@otp@static_supervisor:add(Sup, gleam@otp@supervision:worker(fun() ->
                    start(Pool, Listener_name, erlang:element(4, Pool))
                end))
            end)
        end(_pipe@3),
        gleam@otp@static_supervisor:start(_pipe@4)
    end)),
    _pipe@3 = gleam@otp@static_supervisor:add(_pipe@2, begin
        _pipe@4 = gleam@otp@factory_supervisor:worker_child(fun(Socket) ->
            glisten@internal@handler:start({handler, Socket, erlang:element(2, Pool), erlang:element(5, Pool), erlang:element(6, Pool), erlang:element(7, Pool), erlang:element(8, Pool)})
        end),
        _pipe@5 = gleam@otp@factory_supervisor:named(_pipe@4, erlang:element(4, Pool)),
        _pipe@6 = gleam@otp@factory_supervisor:restart_strategy(_pipe@5, temporary),
        gleam@otp@factory_supervisor:supervised(_pipe@6)
    end),
    gleam@otp@static_supervisor:start(_pipe@3).

