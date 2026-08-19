-record(get_snapshot, {
    player_id :: integer(),
    reply_to :: gleam@erlang@process:subject({ok, binary()} | {error, binary()})
}).
