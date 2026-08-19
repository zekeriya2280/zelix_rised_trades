-record(factory, {
    id :: integer(),
    owner_id :: integer(),
    position :: game_server:position(),
    level :: integer(),
    product :: server@messages:product_type()
}).
