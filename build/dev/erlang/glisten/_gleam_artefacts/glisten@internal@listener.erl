-module(glisten@internal@listener).
-compile([no_auto_import, nowarn_ignored, nowarn_unused_vars, nowarn_unused_function, nowarn_nomatch, inline]).
-export([start/4]).
-export_type([message/0, state/0]).
-moduledoc(false).

-type message() :: {info, gleam@erlang@process:subject(state())}.

-type state() :: {state, glisten@socket:listen_socket(), integer(), glisten@socket@options:ip_address()}.

-file("src\\glisten\\internal\\listener.gleam", 17).
-spec start(integer(), glisten@transport:transport(), list(glisten@socket@options:tcp_option()), gleam@erlang@process:name(message())) -> {ok, gleam@otp@actor:started(gleam@erlang@process:subject(message()))} | {error, gleam@otp@actor:start_error()}.
-doc(false).
start(Port, Transport, Options, Name) ->
    _pipe = gleam@otp@actor:new_with_initialiser(5000, fun(Subject) ->
        _pipe@1 = glisten@transport:listen(Transport, Port, Options),
        _pipe@2 = gleam@result:'try'(_pipe@1, fun(Socket) ->
            _pipe@3 = glisten@transport:sockname(Transport, Socket),
            gleam@result:map(_pipe@3, fun(Info) ->
                {state, Socket, erlang:element(2, Info), erlang:element(1, Info)}
            end)
        end),
        _pipe@3 = gleam@result:map(_pipe@2, fun(State) ->
            _pipe@4 = State,
            _pipe@5 = gleam@otp@actor:initialised(_pipe@4),
            _pipe@6 = gleam@otp@actor:selecting(_pipe@5, begin
                _pipe@7 = gleam_erlang_ffi:new_selector(),
                gleam@erlang@process:select(_pipe@7, Subject)
            end),
            gleam@otp@actor:returning(_pipe@6, Subject)
        end),
        gleam@result:map_error(_pipe@3, fun(Err) ->
            Error_string = <<"Failed to start socket listener: "/utf8, (glisten@socket:reason_to_string(Err))/binary>>,
            logging:log(error, Error_string),
            Error_string
        end)
    end),
    _pipe@1 = gleam@otp@actor:on_message(_pipe, fun(State, Msg) ->
        case Msg of
            {info, Caller} ->
                gleam@erlang@process:send(Caller, State),
                gleam@otp@actor:continue(State)
        end
    end),
    _pipe@2 = gleam@otp@actor:named(_pipe@1, Name),
    gleam@otp@actor:start(_pipe@2).

