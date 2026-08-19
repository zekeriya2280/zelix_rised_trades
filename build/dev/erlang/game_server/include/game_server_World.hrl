-record(world, {
    tick :: integer(),
    next_id :: integer(),
    next_player_id :: integer(),
    players :: list(game_server:player()),
    banks :: list(game_server:bank()),
    factories :: list(game_server:factory()),
    warehouses :: list(game_server:warehouse()),
    gatherers :: list(game_server:simple_building()),
    farms :: list(game_server:simple_building()),
    vehicles :: list(game_server:vehicle()),
    online_players :: list(integer())
}).
