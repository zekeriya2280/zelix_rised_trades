-record(warehouse, {
    id :: integer(),
    owner_id :: integer(),
    position :: game_server:position(),
    capacity :: integer()
}).
