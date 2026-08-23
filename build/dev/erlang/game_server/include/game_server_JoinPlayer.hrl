-record(join_player, {
    auth_uid :: binary(),
    name :: binary(),
    auth_token :: binary(),
    reply_to :: gleam@erlang@process:subject({ok, integer()} | {error, binary()})
}).
