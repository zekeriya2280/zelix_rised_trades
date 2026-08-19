-record(set_factory_product, {
    player_id :: integer(),
    factory_id :: integer(),
    product :: server@messages:product_type(),
    reply_to :: gleam@erlang@process:subject({ok, nil} | {error, binary()})
}).
