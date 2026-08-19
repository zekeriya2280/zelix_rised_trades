-record(spawn_vehicle, {
    player_id :: integer(),
    x :: float(),
    y :: float(),
    target_x :: float(),
    target_y :: float(),
    speed :: float(),
    reply_to :: gleam@erlang@process:subject({ok, nil} | {error, binary()})
}).
