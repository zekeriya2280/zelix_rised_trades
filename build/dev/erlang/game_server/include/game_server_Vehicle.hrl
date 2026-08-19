-record(vehicle, {
    id :: integer(),
    owner_id :: integer(),
    position :: game_server:position(),
    target :: game_server:position(),
    speed :: float()
}).
