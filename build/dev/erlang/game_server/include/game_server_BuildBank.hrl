-record(build_bank, {
    player_id :: integer(),
    x :: float(),
    y :: float(),
    reply_to :: gleam@erlang@process:subject({ok, nil} | {error, binary()})
}).
