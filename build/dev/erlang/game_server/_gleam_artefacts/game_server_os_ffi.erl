-module(game_server_os_ffi).
-export([get_env/1, read_project_file/1, terrain_height/2]).

get_env(Key) ->
  case os:getenv(binary_to_list(Key)) of
    false -> {error, nil};
    Value -> {ok, list_to_binary(Value)}
  end.

%% Shared deterministic terrain function. The client uses the same formula,
%% keeping visual terrain and server placement authority in sync without
%% sending a 100x100 terrain grid over the network.
terrain_height(X, Y) ->
    math:sin(X / 180.0) * 0.45 +
    math:cos(Y / 230.0) * 0.35 +
    math:sin((X + Y) / 310.0) * 0.20.

read_project_file(Name) ->
  case file:read_file(binary_to_list(Name)) of
    {ok, Value} -> {ok, Value};
    {error, _} -> {error, nil}
  end.
