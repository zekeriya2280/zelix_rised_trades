-module(server@websocket).
-compile([no_auto_import, nowarn_ignored, nowarn_unused_vars, nowarn_unused_function, nowarn_nomatch, inline]).
-export([start/1]).

-file("src\\server\\websocket.gleam", 6).
-spec start(gleam@erlang@process:subject(game_server:message())) -> {ok, gleam@otp@actor:started(gleam@otp@static_supervisor:supervisor())} | {error, gleam@otp@actor:start_error()}.
start(World) ->
    Builder = begin
        _pipe = mist:new(fun(Request) ->
            server@router:handle(Request, World)
        end),
        _pipe@1 = mist:bind(_pipe, ~"0.0.0.0"),
        mist:port(_pipe@1, 8765)
    end,
    mist:start(Builder).

