-module(main).
-compile([no_auto_import, nowarn_ignored, nowarn_unused_vars, nowarn_unused_function, nowarn_nomatch, inline]).
-export([main/0]).

-file("src\\main.gleam", 5).
-spec main() -> nil.
main() ->
    World = game_server:start(),
    _ = server@websocket:start(World),
    gleam_erlang_ffi:sleep_forever().

