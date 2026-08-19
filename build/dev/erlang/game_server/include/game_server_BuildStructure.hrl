-record(build_structure, {
    player_id :: integer(),
    building :: server@messages:building_type(),
    x :: float(),
    y :: float(),
    reply_to :: gleam@erlang@process:subject({ok, nil} | {error, binary()})
}).
