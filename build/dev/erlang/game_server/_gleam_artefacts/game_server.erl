-module(game_server).
-compile([no_auto_import, nowarn_ignored, nowarn_unused_vars, nowarn_unused_function, nowarn_nomatch, inline]).
-export([initial_world/0, snapshot_json/2, start/0, handle_test_factory/3]).
-export_type([position/0, player/0, bank/0, factory/0, warehouse/0, simple_building/0, vehicle/0, room/0, world/0, message/0]).

-type position() :: {position, float(), float()}.

-type player() :: {player, integer(), binary(), binary(), binary(), integer(), integer(), integer(), integer(), integer(), integer()}.

-type bank() :: {bank, integer(), integer(), position()}.

-type factory() :: {factory, integer(), integer(), position(), integer(), server@messages:product_type()}.

-type warehouse() :: {warehouse, integer(), integer(), position(), integer()}.

-type simple_building() :: {simple_building, integer(), integer(), position()}.

-type vehicle() :: {vehicle, integer(), integer(), position(), position(), float()}.

-type room() :: {room, binary(), integer(), binary(), list(integer()), boolean()}.

-type world() :: {world, integer(), integer(), integer(), list(player()), list(bank()), list(factory()), list(warehouse()), list(simple_building()), list(simple_building()), list(vehicle()), list(integer()), list(room()), integer()}.

-type message() :: {join_player, binary(), binary(), binary(), gleam@erlang@process:subject({ok, integer()} | {error, binary()})} | {leave_player, integer()} | {build_bank, integer(), float(), float(), gleam@erlang@process:subject({ok, nil} | {error, binary()})} | {build_structure, integer(), server@messages:building_type(), float(), float(), gleam@erlang@process:subject({ok, nil} | {error, binary()})} | {spawn_vehicle, integer(), float(), float(), float(), float(), float(), gleam@erlang@process:subject({ok, nil} | {error, binary()})} | {set_factory_product, integer(), integer(), server@messages:product_type(), gleam@erlang@process:subject({ok, nil} | {error, binary()})} | {create_room, integer(), binary(), gleam@erlang@process:subject({ok, binary()} | {error, binary()})} | {join_room, integer(), binary(), gleam@erlang@process:subject({ok, binary()} | {error, binary()})} | {start_room, integer(), gleam@erlang@process:subject({ok, nil} | {error, binary()})} | {leave_room, integer(), gleam@erlang@process:subject({ok, nil} | {error, binary()})} | {get_lobby, integer(), gleam@erlang@process:subject({ok, binary()} | {error, binary()})} | {get_snapshot, integer(), gleam@erlang@process:subject({ok, binary()} | {error, binary()})}.

-file("src\\game_server.gleam", 92).
-spec initial_world() -> world().
initial_world() ->
    {world, 0, 1, 1, [], [], [], [], [], [], [], [], [], 1}.

-file("src\\game_server.gleam", 546).
-spec add_product(player(), server@messages:product_type(), integer()) -> player().
add_product(Player, Product, Amount) ->
    case Product of
        wood ->
            {player, erlang:element(2, Player), erlang:element(3, Player), erlang:element(4, Player), erlang:element(5, Player), erlang:element(6, Player), erlang:element(7, Player) + Amount, erlang:element(8, Player), erlang:element(9, Player), erlang:element(10, Player), erlang:element(11, Player)};

        stone ->
            {player, erlang:element(2, Player), erlang:element(3, Player), erlang:element(4, Player), erlang:element(5, Player), erlang:element(6, Player), erlang:element(7, Player), erlang:element(8, Player) + Amount, erlang:element(9, Player), erlang:element(10, Player), erlang:element(11, Player)};

        iron ->
            {player, erlang:element(2, Player), erlang:element(3, Player), erlang:element(4, Player), erlang:element(5, Player), erlang:element(6, Player), erlang:element(7, Player), erlang:element(8, Player), erlang:element(9, Player) + Amount, erlang:element(10, Player), erlang:element(11, Player)};

        gold ->
            {player, erlang:element(2, Player), erlang:element(3, Player), erlang:element(4, Player), erlang:element(5, Player), erlang:element(6, Player), erlang:element(7, Player), erlang:element(8, Player), erlang:element(9, Player), erlang:element(10, Player) + Amount, erlang:element(11, Player)};

        grain ->
            {player, erlang:element(2, Player), erlang:element(3, Player), erlang:element(4, Player), erlang:element(5, Player), erlang:element(6, Player), erlang:element(7, Player), erlang:element(8, Player), erlang:element(9, Player), erlang:element(10, Player), erlang:element(11, Player) + Amount}
    end.

-file("src\\game_server.gleam", 533).
-spec inventory_total(player()) -> integer().
inventory_total(Player) ->
    (((erlang:element(7, Player) + erlang:element(8, Player)) + erlang:element(9, Player)) + erlang:element(10, Player)) + erlang:element(11, Player).

-file("src\\game_server.gleam", 535).
-spec positive_or_zero(integer()) -> integer().
positive_or_zero(Value) ->
    case Value > 0 of
        true ->
            Value;

        false ->
            0
    end.

-file("src\\game_server.gleam", 539).
-spec add_product_capped(player(), server@messages:product_type(), integer(), integer()) -> player().
add_product_capped(Player, Product, Amount, Capacity) ->
    Room = positive_or_zero(Capacity - inventory_total(Player)),
    Amount@1 = case Amount < Room of
        true ->
            Amount;

        false ->
            Room
    end,
    Updated = add_product(Player, Product, Amount@1),
    {player, erlang:element(2, Updated), erlang:element(3, Updated), erlang:element(4, Updated), erlang:element(5, Updated), erlang:element(6, Updated) + (server@messages:product_value(Product) * Amount@1), erlang:element(7, Updated), erlang:element(8, Updated), erlang:element(9, Updated), erlang:element(10, Updated), erlang:element(11, Updated)}.

-file("src\\game_server.gleam", 241).
-spec produce_for_player(player(), list(factory()), list(warehouse())) -> player().
produce_for_player(Player, Factories, Warehouses) ->
    Capacity = gleam@list:fold(Warehouses, 0, fun(Total, Warehouse) ->
        case erlang:element(3, Warehouse) =:= erlang:element(2, Player) of
            true ->
                Total + erlang:element(5, Warehouse);

            false ->
                Total
        end
    end),
    Used = inventory_total(Player),
    Room = positive_or_zero(Capacity - Used),
    case Room =:= 0 of
        true ->
            Player;

        false ->
            gleam@list:fold(Factories, Player, fun(Current, Factory) ->
                case erlang:element(3, Factory) =:= erlang:element(2, Player) of
                    false ->
                        Current;

                    true ->
                        add_product_capped(Current, erlang:element(6, Factory), erlang:element(5, Factory), Capacity)
                end
            end)
    end.

-file("src\\game_server.gleam", 442).
-spec distance(position(), position()) -> float().
distance(A, B) ->
    Dx = erlang:element(2, B) - erlang:element(2, A),
    Dy = erlang:element(3, B) - erlang:element(3, A),
    case gleam@float:square_root((Dx * Dx) + (Dy * Dy)) of
        {ok, Value} ->
            Value;

        {error, nil} ->
            +0.0
    end.

-file("src\\game_server.gleam", 513).
-spec move_vehicle(vehicle()) -> vehicle().
move_vehicle(Vehicle) ->
    {position, X, Y} = erlang:element(4, Vehicle),
    {position, Tx, Ty} = erlang:element(5, Vehicle),
    Dx = Tx - X,
    Dy = Ty - Y,
    D = distance(erlang:element(4, Vehicle), erlang:element(5, Vehicle)),
    Step = erlang:element(6, Vehicle) * 0.05,
    case (D =< Step) orelse (D =< 0.001) of
        true ->
            {vehicle, erlang:element(2, Vehicle), erlang:element(3, Vehicle), erlang:element(5, Vehicle), erlang:element(5, Vehicle), erlang:element(6, Vehicle)};

        false ->
            {vehicle, erlang:element(2, Vehicle), erlang:element(3, Vehicle), {position, X + (case D of
                +0.0 ->
                    +0.0;

                -0.0 ->
                    -0.0;

                _value ->
                    Dx / _value
            end * Step), Y + (case D of
                +0.0 ->
                    +0.0;

                -0.0 ->
                    -0.0;

                _value@1 ->
                    Dy / _value@1
            end * Step)}, erlang:element(5, Vehicle), erlang:element(6, Vehicle)}
    end.

-file("src\\game_server.gleam", 230).
-spec update(world()) -> world().
update(World) ->
    Next_tick = erlang:element(2, World) + 1,
    Vehicles = gleam@list:map(erlang:element(11, World), fun move_vehicle/1),
    Players = case case 20 of
        0 ->
            0;

        _value ->
            Next_tick rem _value
    end =:= 0 of
        true ->
            gleam@list:map(erlang:element(5, World), fun(Player) ->
                produce_for_player(Player, erlang:element(7, World), erlang:element(8, World))
            end);

        false ->
            erlang:element(5, World)
    end,
    {world, Next_tick, erlang:element(3, World), erlang:element(4, World), Players, erlang:element(6, World), erlang:element(7, World), erlang:element(8, World), erlang:element(9, World), erlang:element(10, World), Vehicles, erlang:element(12, World), erlang:element(13, World), erlang:element(14, World)}.

-file("src\\game_server.gleam", 850).
-spec vehicle_json(vehicle()) -> gleam@json:json().
vehicle_json(Vehicle) ->
    {position, X, Y} = erlang:element(4, Vehicle),
    {position, Tx, Ty} = erlang:element(5, Vehicle),
    gleam@json:object([{~"id", gleam@json:int(erlang:element(2, Vehicle))}, {~"owner_id", gleam@json:int(erlang:element(3, Vehicle))}, {~"x", gleam@json:float(X)}, {~"y", gleam@json:float(Y)}, {~"target_x", gleam@json:float(Tx)}, {~"target_y", gleam@json:float(Ty)}, {~"speed", gleam@json:float(erlang:element(6, Vehicle))}]).

-file("src\\game_server.gleam", 846).
-spec simple_json(simple_building()) -> gleam@json:json().
simple_json(Building) ->
    {position, X, Y} = erlang:element(4, Building),
    gleam@json:object([{~"id", gleam@json:int(erlang:element(2, Building))}, {~"owner_id", gleam@json:int(erlang:element(3, Building))}, {~"x", gleam@json:float(X)}, {~"y", gleam@json:float(Y)}]).

-file("src\\game_server.gleam", 842).
-spec warehouse_json(warehouse()) -> gleam@json:json().
warehouse_json(Warehouse) ->
    {position, X, Y} = erlang:element(4, Warehouse),
    gleam@json:object([{~"id", gleam@json:int(erlang:element(2, Warehouse))}, {~"owner_id", gleam@json:int(erlang:element(3, Warehouse))}, {~"x", gleam@json:float(X)}, {~"y", gleam@json:float(Y)}, {~"capacity", gleam@json:int(erlang:element(5, Warehouse))}]).

-file("src\\game_server.gleam", 838).
-spec factory_json(factory()) -> gleam@json:json().
factory_json(Factory) ->
    {position, X, Y} = erlang:element(4, Factory),
    gleam@json:object([{~"id", gleam@json:int(erlang:element(2, Factory))}, {~"owner_id", gleam@json:int(erlang:element(3, Factory))}, {~"x", gleam@json:float(X)}, {~"y", gleam@json:float(Y)}, {~"level", gleam@json:int(erlang:element(5, Factory))}, {~"product", server@messages:product_json(erlang:element(6, Factory))}]).

-file("src\\game_server.gleam", 834).
-spec bank_json(bank()) -> gleam@json:json().
bank_json(Bank) ->
    {position, X, Y} = erlang:element(4, Bank),
    gleam@json:object([{~"id", gleam@json:int(erlang:element(2, Bank))}, {~"owner_id", gleam@json:int(erlang:element(3, Bank))}, {~"x", gleam@json:float(X)}, {~"y", gleam@json:float(Y)}]).

-file("src\\game_server.gleam", 572).
-spec player_in_started_room(world(), integer()) -> boolean().
player_in_started_room(World, Player_id) ->
    gleam@list:any(erlang:element(13, World), fun(Room) ->
        erlang:element(6, Room) andalso gleam@list:any(erlang:element(5, Room), fun(Id) ->
            Id =:= Player_id
        end)
    end).

-file("src\\game_server.gleam", 576).
-spec player_room(world(), integer()) -> gleam@option:option(room()).
player_room(World, Player_id) ->
    gleam@list:fold(erlang:element(13, World), none, fun(Found, Room) ->
        case Found of
            {some, _} ->
                Found;

            none ->
                case gleam@list:any(erlang:element(5, Room), fun(Id) ->
                    Id =:= Player_id
                end) of
                    true ->
                        {some, Room};

                    false ->
                        none
                end
        end
    end).

-file("src\\game_server.gleam", 556).
-spec player_storage_capacity(world(), integer()) -> integer().
player_storage_capacity(World, Player_id) ->
    gleam@list:fold(erlang:element(8, World), 0, fun(Total, Warehouse) ->
        case erlang:element(3, Warehouse) =:= Player_id of
            true ->
                Total + erlang:element(5, Warehouse);

            false ->
                Total
        end
    end).

-file("src\\game_server.gleam", 562).
-spec inventory_json(player()) -> gleam@json:json().
inventory_json(Player) ->
    gleam@json:object([{~"wood", gleam@json:int(erlang:element(7, Player))}, {~"stone", gleam@json:int(erlang:element(8, Player))}, {~"iron", gleam@json:int(erlang:element(9, Player))}, {~"gold", gleam@json:int(erlang:element(10, Player))}, {~"grain", gleam@json:int(erlang:element(11, Player))}]).

-file("src\\game_server.gleam", 487).
-spec player_money(world(), integer()) -> integer().
player_money(World, Player_id) ->
    gleam@list:fold(erlang:element(5, World), 0, fun(Money, Player) ->
        case erlang:element(2, Player) =:= Player_id of
            true ->
                erlang:element(6, Player);

            false ->
                Money
        end
    end).

-file("src\\game_server.gleam", 526).
-spec get_player(list(player()), integer()) -> player().
get_player(Players, Player_id) ->
    case Players of
        [Player | Rest] ->
            case erlang:element(2, Player) =:= Player_id of
                true ->
                    Player;

                false ->
                    get_player(Rest, Player_id)
            end;

        [] ->
            {player, Player_id, ~"", ~"", ~"", 0, 0, 0, 0, 0, 0}
    end.

-file("src\\game_server.gleam", 463).
-spec is_online(world(), integer()) -> boolean().
is_online(World, Player_id) ->
    gleam@list:any(erlang:element(12, World), fun(Id) ->
        Id =:= Player_id
    end).

-file("src\\game_server.gleam", 461).
-spec player_exists(world(), integer()) -> boolean().
player_exists(World, Player_id) ->
    gleam@list:any(erlang:element(5, World), fun(Player) ->
        erlang:element(2, Player) =:= Player_id
    end).

-file("src\\game_server.gleam", 465).
-spec session_valid(world(), integer()) -> boolean().
session_valid(World, Player_id) ->
    player_exists(World, Player_id) andalso is_online(World, Player_id).

-file("src\\game_server.gleam", 799).
-spec snapshot_json(world(), integer()) -> {ok, binary()} | {error, binary()}.
snapshot_json(World, Player_id) ->
    case session_valid(World, Player_id) of
        false ->
            {error, ~"Player session is not valid."};

        true ->
            Player = get_player(erlang:element(5, World), Player_id),
            Money = player_money(World, Player_id),
            Inventory = inventory_json(Player),
            Storage_capacity = player_storage_capacity(World, Player_id),
            Room_players = case player_room(World, Player_id) of
                {some, Room} ->
                    erlang:element(5, Room);

                none ->
                    [Player_id]
            end,
            Visible_owner = fun(Owner_id) ->
                gleam@list:any(Room_players, fun(Id) ->
                    Id =:= Owner_id
                end)
            end,
            Data = gleam@json:object([{~"tick", gleam@json:int(erlang:element(2, World))}, {~"money", gleam@json:int(Money)}, {~"inventory", Inventory}, {~"storage_used", gleam@json:int(inventory_total(Player))}, {~"storage_capacity", gleam@json:int(Storage_capacity)}, {~"in_game", gleam@json:bool(player_in_started_room(World, Player_id))}, {~"banks", gleam@json:array(gleam@list:filter(erlang:element(6, World), fun(Item) ->
                Visible_owner(erlang:element(3, Item))
            end), fun bank_json/1)}, {~"factories", gleam@json:array(gleam@list:filter(erlang:element(7, World), fun(Item) ->
                Visible_owner(erlang:element(3, Item))
            end), fun factory_json/1)}, {~"warehouses", gleam@json:array(gleam@list:filter(erlang:element(8, World), fun(Item) ->
                Visible_owner(erlang:element(3, Item))
            end), fun warehouse_json/1)}, {~"gatherers", gleam@json:array(gleam@list:filter(erlang:element(9, World), fun(Item) ->
                Visible_owner(erlang:element(3, Item))
            end), fun simple_json/1)}, {~"farms", gleam@json:array(gleam@list:filter(erlang:element(10, World), fun(Item) ->
                Visible_owner(erlang:element(3, Item))
            end), fun simple_json/1)}, {~"vehicles", gleam@json:array(gleam@list:filter(erlang:element(11, World), fun(Item) ->
                Visible_owner(erlang:element(3, Item))
            end), fun vehicle_json/1)}]),
            Envelope = gleam@json:object([{~"type", gleam@json:string(~"world_snapshot")}, {~"data", Data}]),
            {ok, begin
                _pipe = Envelope,
                gleam@json:to_string(_pipe)
            end}
    end.

-file("src\\game_server.gleam", 795).
-spec player_name(world(), integer()) -> binary().
player_name(World, Player_id) ->
    gleam@list:fold(erlang:element(5, World), ~"Player", fun(Current, Player) ->
        case erlang:element(2, Player) =:= Player_id of
            true ->
                erlang:element(4, Player);

            false ->
                Current
        end
    end).

-file("src\\game_server.gleam", 756).
-spec lobby_json(world(), integer()) -> {ok, binary()} | {error, binary()}.
lobby_json(World, Player_id) ->
    Current = player_room(World, Player_id),
    Room_payloads = begin
        _pipe = erlang:element(13, World),
        _pipe@1 = gleam@list:filter(_pipe, fun(Room) ->
            not erlang:element(6, Room)
        end),
        gleam@list:map(_pipe@1, fun(Room) ->
            {room_summary, erlang:element(2, Room), player_name(World, erlang:element(3, Room)), erlang:element(4, Room), gleam@list:map(erlang:element(5, Room), fun(Id) ->
                player_name(World, Id)
            end), 5, erlang:element(6, Room)}
        end)
    end,
    {Room_id, Is_host, Started, Mode, Host_name, Players} = case Current of
        none ->
            {none, false, false, ~"online", ~"", []};

        {some, Room} ->
            {{some, erlang:element(2, Room)}, erlang:element(3, Room) =:= Player_id, erlang:element(6, Room), erlang:element(4, Room), player_name(World, erlang:element(3, Room)), gleam@list:map(erlang:element(5, Room), fun(Id) ->
                player_name(World, Id)
            end)}
    end,
    {ok, server@messages:encode_server({lobby_state, Room_id, Is_host, Started, Mode, Host_name, Players, 5, Room_payloads})}.

-file("src\\game_server.gleam", 731).
-spec replace_room(world(), room()) -> world().
replace_room(World, Updated) ->
    {world, erlang:element(2, World), erlang:element(3, World), erlang:element(4, World), erlang:element(5, World), erlang:element(6, World), erlang:element(7, World), erlang:element(8, World), erlang:element(9, World), erlang:element(10, World), erlang:element(11, World), erlang:element(12, World), gleam@list:map(erlang:element(13, World), fun(Room) ->
        case erlang:element(2, Room) =:= erlang:element(2, Updated) of
            true ->
                Updated;

            false ->
                Room
        end
    end), erlang:element(14, World)}.

-file("src\\game_server.gleam", 724).
-spec hd(list(integer())) -> integer().
hd(Ids) ->
    case Ids of
        [First | _] ->
            First;

        [] ->
            0
    end.

-file("src\\game_server.gleam", 683).
-spec reset_player_match_state(world(), integer()) -> world().
reset_player_match_state(World, Player_id) ->
    Players = gleam@list:map(erlang:element(5, World), fun(Player) ->
        case erlang:element(2, Player) =:= Player_id of
            true ->
                {player, erlang:element(2, Player), erlang:element(3, Player), erlang:element(4, Player), erlang:element(5, Player), 100000, 0, 0, 0, 0, 0};

            false ->
                Player
        end
    end),
    {world, erlang:element(2, World), erlang:element(3, World), erlang:element(4, World), Players, gleam@list:filter(erlang:element(6, World), fun(Item) ->
        erlang:element(3, Item) /= Player_id
    end), gleam@list:filter(erlang:element(7, World), fun(Item) ->
        erlang:element(3, Item) /= Player_id
    end), gleam@list:filter(erlang:element(8, World), fun(Item) ->
        erlang:element(3, Item) /= Player_id
    end), gleam@list:filter(erlang:element(9, World), fun(Item) ->
        erlang:element(3, Item) /= Player_id
    end), gleam@list:filter(erlang:element(10, World), fun(Item) ->
        erlang:element(3, Item) /= Player_id
    end), gleam@list:filter(erlang:element(11, World), fun(Item) ->
        erlang:element(3, Item) /= Player_id
    end), erlang:element(12, World), erlang:element(13, World), erlang:element(14, World)}.

-file("src\\game_server.gleam", 735).
-spec remove_room(world(), binary()) -> world().
remove_room(World, Room_id) ->
    {world, erlang:element(2, World), erlang:element(3, World), erlang:element(4, World), erlang:element(5, World), erlang:element(6, World), erlang:element(7, World), erlang:element(8, World), erlang:element(9, World), erlang:element(10, World), erlang:element(11, World), erlang:element(12, World), gleam@list:filter(erlang:element(13, World), fun(Room) ->
        erlang:element(2, Room) /= Room_id
    end), erlang:element(14, World)}.

-file("src\\game_server.gleam", 702).
-spec reset_room_match_state(world(), list(integer())) -> world().
reset_room_match_state(World, Player_ids) ->
    Players = gleam@list:map(erlang:element(5, World), fun(Player) ->
        case gleam@list:any(Player_ids, fun(Id) ->
            Id =:= erlang:element(2, Player)
        end) of
            true ->
                {player, erlang:element(2, Player), erlang:element(3, Player), erlang:element(4, Player), erlang:element(5, Player), 100000, 0, 0, 0, 0, 0};

            false ->
                Player
        end
    end),
    Belongs_to_room = fun(Owner_id) ->
        gleam@list:any(Player_ids, fun(Id) ->
            Id =:= Owner_id
        end)
    end,
    {world, erlang:element(2, World), erlang:element(3, World), erlang:element(4, World), Players, gleam@list:filter(erlang:element(6, World), fun(Item) ->
        not Belongs_to_room(erlang:element(3, Item))
    end), gleam@list:filter(erlang:element(7, World), fun(Item) ->
        not Belongs_to_room(erlang:element(3, Item))
    end), gleam@list:filter(erlang:element(8, World), fun(Item) ->
        not Belongs_to_room(erlang:element(3, Item))
    end), gleam@list:filter(erlang:element(9, World), fun(Item) ->
        not Belongs_to_room(erlang:element(3, Item))
    end), gleam@list:filter(erlang:element(10, World), fun(Item) ->
        not Belongs_to_room(erlang:element(3, Item))
    end), gleam@list:filter(erlang:element(11, World), fun(Item) ->
        not Belongs_to_room(erlang:element(3, Item))
    end), erlang:element(12, World), erlang:element(13, World), erlang:element(14, World)}.

-file("src\\game_server.gleam", 659).
-spec leave_room(world(), integer()) -> {world(), {ok, nil} | {error, binary()}}.
leave_room(World, Player_id) ->
    case player_room(World, Player_id) of
        none ->
            {World, {ok, nil}};

        {some, Room} ->
            Players = gleam@list:filter(erlang:element(5, Room), fun(Id) ->
                Id /= Player_id
            end),
            World@1 = case Players of
                [] ->
                    reset_room_match_state(remove_room(World, erlang:element(2, Room)), erlang:element(5, Room));

                _ ->
                    Cleaned = case erlang:element(6, Room) of
                        true ->
                            reset_player_match_state(World, Player_id);

                        false ->
                            World
                    end,
                    New_host = case erlang:element(3, Room) =:= Player_id of
                        true ->
                            hd(Players);

                        false ->
                            erlang:element(3, Room)
                    end,
                    Updated = {room, erlang:element(2, Room), New_host, erlang:element(4, Room), Players, erlang:element(6, Room)},
                    Host = get_player(erlang:element(5, Cleaned), New_host),
                    server@firestore:save_room(erlang:element(5, Host), erlang:element(2, Updated), erlang:element(3, Updated), erlang:element(4, Updated), erlang:element(5, Updated), erlang:element(6, Updated)),
                    replace_room(Cleaned, Updated)
            end,
            {World@1, {ok, nil}}
    end.

-file("src\\game_server.gleam", 637).
-spec start_room(world(), integer()) -> {world(), {ok, nil} | {error, binary()}}.
start_room(World, Player_id) ->
    case player_room(World, Player_id) of
        none ->
            {World, {error, ~"You are not in a room."}};

        {some, Room} ->
            case erlang:element(3, Room) =:= Player_id of
                false ->
                    {World, {error, ~"Only the host can start the room."}};

                true ->
                    case erlang:length(erlang:element(5, Room)) < 2 of
                        true ->
                            {World, {error, ~"At least 2 players are required to start the room."}};

                        false ->
                            Prepared = reset_room_match_state(World, erlang:element(5, Room)),
                            Updated = {room, erlang:element(2, Room), erlang:element(3, Room), erlang:element(4, Room), erlang:element(5, Room), true},
                            Host = get_player(erlang:element(5, Prepared), erlang:element(3, Room)),
                            server@firestore:save_room(erlang:element(5, Host), erlang:element(2, Room), erlang:element(3, Room), erlang:element(4, Room), erlang:element(5, Updated), true),
                            {replace_room(Prepared, Updated), {ok, nil}}
                    end
            end
    end.

-file("src\\game_server.gleam", 585).
-spec room_by_id(world(), binary()) -> gleam@option:option(room()).
room_by_id(World, Code) ->
    Normalized = string:uppercase(gleam@string:trim(Code)),
    gleam@list:fold(erlang:element(13, World), none, fun(Found, Room) ->
        case Found of
            {some, _} ->
                Found;

            none ->
                case string:uppercase(erlang:element(2, Room)) =:= Normalized of
                    true ->
                        {some, Room};

                    false ->
                        none
                end
        end
    end).

-file("src\\game_server.gleam", 613).
-spec join_room(world(), integer(), binary()) -> {world(), {ok, binary()} | {error, binary()}}.
join_room(World, Player_id, Code) ->
    case session_valid(World, Player_id) of
        false ->
            {World, {error, ~"Authentication required."}};

        true ->
            case player_room(World, Player_id) of
                {some, Existing} ->
                    {World, {error, <<<<"You are already in room "/utf8, (erlang:element(2, Existing))/binary>>/binary, "."/utf8>>}};

                none ->
                    case room_by_id(World, Code) of
                        none ->
                            {World, {error, ~"Room not found."}};

                        {some, Room} ->
                            case erlang:element(6, Room) of
                                true ->
                                    {World, {error, ~"Room has already started."}};

                                false ->
                                    case erlang:length(erlang:element(5, Room)) >= 5 of
                                        true ->
                                            {World, {error, ~"Room is full."}};

                                        false ->
                                            Updated = {room, erlang:element(2, Room), erlang:element(3, Room), erlang:element(4, Room), [Player_id | erlang:element(5, Room)], erlang:element(6, Room)},
                                            Host = get_player(erlang:element(5, World), erlang:element(3, Room)),
                                            server@firestore:save_room(erlang:element(5, Host), erlang:element(2, Room), erlang:element(3, Room), erlang:element(4, Room), erlang:element(5, Updated), erlang:element(6, Updated)),
                                            {replace_room(World, Updated), {ok, erlang:element(2, Room)}}
                                    end
                            end
                    end
            end
    end.

-file("src\\game_server.gleam", 749).
-spec safe_mode(binary()) -> binary().
safe_mode(Mode) ->
    case string:lowercase(gleam@string:trim(Mode)) of
        ~"online" ->
            ~"online";

        _ ->
            ~"multiplayer"
    end.

-file("src\\game_server.gleam", 739).
-spec room_code(integer()) -> binary().
room_code(Value) ->
    Text = erlang:integer_to_binary(Value),
    case string:length(Text) of
        1 ->
            <<"RM000"/utf8, Text/binary>>;

        2 ->
            <<"RM00"/utf8, Text/binary>>;

        3 ->
            <<"RM0"/utf8, Text/binary>>;

        _ ->
            <<"RM"/utf8, Text/binary>>
    end.

-file("src\\game_server.gleam", 595).
-spec create_room(world(), integer(), binary()) -> {world(), {ok, binary()} | {error, binary()}}.
create_room(World, Player_id, Mode) ->
    case session_valid(World, Player_id) of
        false ->
            {World, {error, ~"Authentication required."}};

        true ->
            case player_room(World, Player_id) of
                {some, _} ->
                    {World, {error, ~"You are already in a room."}};

                none ->
                    Code = room_code(erlang:element(14, World)),
                    Mode@1 = safe_mode(Mode),
                    Room = {room, Code, Player_id, Mode@1, [Player_id], false},
                    Host = get_player(erlang:element(5, World), Player_id),
                    server@firestore:save_player(erlang:element(5, Host), erlang:element(3, Host), erlang:element(4, Host)),
                    server@firestore:save_room(erlang:element(5, Host), Code, Player_id, Mode@1, [Player_id], false),
                    {{world, erlang:element(2, World), erlang:element(3, World), erlang:element(4, World), erlang:element(5, World), erlang:element(6, World), erlang:element(7, World), erlang:element(8, World), erlang:element(9, World), erlang:element(10, World), erlang:element(11, World), erlang:element(12, World), [Room | erlang:element(13, World)], erlang:element(14, World) + 1}, {ok, Code}}
            end
    end.

-file("src\\game_server.gleam", 350).
-spec set_factory_product(world(), integer(), integer(), server@messages:product_type()) -> {world(), {ok, nil} | {error, binary()}}.
set_factory_product(World, Player_id, Factory_id, Product) ->
    Found = gleam@list:any(erlang:element(7, World), fun(Factory) ->
        (erlang:element(2, Factory) =:= Factory_id) andalso (erlang:element(3, Factory) =:= Player_id)
    end),
    case Found of
        false ->
            {World, {error, ~"Factory not found or not owned by player."}};

        true ->
            Factories = gleam@list:map(erlang:element(7, World), fun(Factory) ->
                case (erlang:element(2, Factory) =:= Factory_id) andalso (erlang:element(3, Factory) =:= Player_id) of
                    true ->
                        {factory, erlang:element(2, Factory), erlang:element(3, Factory), erlang:element(4, Factory), erlang:element(5, Factory), Product};

                    false ->
                        Factory
                end
            end),
            {{world, erlang:element(2, World), erlang:element(3, World), erlang:element(4, World), erlang:element(5, World), erlang:element(6, World), Factories, erlang:element(8, World), erlang:element(9, World), erlang:element(10, World), erlang:element(11, World), erlang:element(12, World), erlang:element(13, World), erlang:element(14, World)}, {ok, nil}}
    end.

-file("src\\game_server.gleam", 346).
-spec same_position(position(), position()) -> boolean().
same_position(A, B) ->
    distance(A, B) =< 1.0.

-file("src\\game_server.gleam", 337).
-spec owned_destination_at(world(), integer(), float(), float()) -> boolean().
owned_destination_at(World, Player_id, X, Y) ->
    gleam@list:any(erlang:element(7, World), fun(Factory) ->
        (erlang:element(3, Factory) =:= Player_id) andalso same_position(erlang:element(4, Factory), {position, X, Y})
    end) orelse gleam@list:any(erlang:element(8, World), fun(Warehouse) ->
        (erlang:element(3, Warehouse) =:= Player_id) andalso same_position(erlang:element(4, Warehouse), {position, X, Y})
    end).

-file("src\\game_server.gleam", 331).
-spec owned_factory_at(world(), integer(), float(), float()) -> boolean().
owned_factory_at(World, Player_id, X, Y) ->
    gleam@list:any(erlang:element(7, World), fun(Factory) ->
        (erlang:element(3, Factory) =:= Player_id) andalso same_position(erlang:element(4, Factory), {position, X, Y})
    end).

-file("src\\game_server.gleam", 416).
-spec validate_coordinate(float()) -> boolean().
validate_coordinate(Value) ->
    (Value > (+0.0 - 1000.0)) andalso (Value =< 1000.0).

-file("src\\game_server.gleam", 467).
-spec player_authorized(world(), integer()) -> boolean().
player_authorized(World, Player_id) ->
    session_valid(World, Player_id) andalso player_in_started_room(World, Player_id).

-file("src\\game_server.gleam", 311).
-spec spawn_vehicle(world(), integer(), float(), float(), float(), float(), float()) -> {world(), {ok, nil} | {error, binary()}}.
spawn_vehicle(World, Player_id, X, Y, Tx, Ty, Speed) ->
    case (((player_authorized(World, Player_id) andalso validate_coordinate(X)) andalso validate_coordinate(Y)) andalso validate_coordinate(Tx)) andalso validate_coordinate(Ty) of
        false ->
            {World, {error, ~"Invalid vehicle position or player session."}};

        true ->
            case (Speed > +0.0) andalso (Speed =< 500.0) of
                false ->
                    {World, {error, ~"Invalid vehicle speed."}};

                true ->
                    case owned_factory_at(World, Player_id, X, Y) of
                        false ->
                            {World, {error, ~"Vehicle source must be one of your factories."}};

                        true ->
                            case owned_destination_at(World, Player_id, Tx, Ty) of
                                false ->
                                    {World, {error, ~"Vehicle target must be one of your factories or warehouses."}};

                                true ->
                                    Id = erlang:element(3, World),
                                    Vehicle = {vehicle, Id, Player_id, {position, X, Y}, {position, Tx, Ty}, Speed},
                                    {{world, erlang:element(2, World), Id + 1, erlang:element(4, World), erlang:element(5, World), erlang:element(6, World), erlang:element(7, World), erlang:element(8, World), erlang:element(9, World), erlang:element(10, World), [Vehicle | erlang:element(11, World)], erlang:element(12, World), erlang:element(13, World), erlang:element(14, World)}, {ok, nil}}
                            end
                    end
            end
    end.

-file("src\\game_server.gleam", 496).
-spec spend(world(), integer(), integer()) -> world().
spend(World, Player_id, Amount) ->
    Players = gleam@list:map(erlang:element(5, World), fun(Player) ->
        case erlang:element(2, Player) =:= Player_id of
            true ->
                {player, erlang:element(2, Player), erlang:element(3, Player), erlang:element(4, Player), erlang:element(5, Player), erlang:element(6, Player) - Amount, erlang:element(7, Player), erlang:element(8, Player), erlang:element(9, Player), erlang:element(10, Player), erlang:element(11, Player)};

            false ->
                Player
        end
    end),
    {world, erlang:element(2, World), erlang:element(3, World), erlang:element(4, World), Players, erlang:element(6, World), erlang:element(7, World), erlang:element(8, World), erlang:element(9, World), erlang:element(10, World), erlang:element(11, World), erlang:element(12, World), erlang:element(13, World), erlang:element(14, World)}.

-file("src\\game_server.gleam", 438).
-spec inside_owned_city(world(), integer(), float(), float()) -> boolean().
inside_owned_city(World, Player_id, X, Y) ->
    gleam@list:any(erlang:element(6, World), fun(Bank) ->
        (erlang:element(3, Bank) =:= Player_id) andalso (distance(erlang:element(4, Bank), {position, X, Y}) =< 300.0)
    end).

-file("src\\game_server.gleam", 306).
-spec warehouse_connected(world(), integer(), float(), float()) -> boolean().
warehouse_connected(World, Player_id, X, Y) ->
    gleam@list:any(erlang:element(6, World), fun(Bank) ->
        (erlang:element(3, Bank) =:= Player_id) andalso (distance(erlang:element(4, Bank), {position, X, Y}) =< 300.0)
    end) orelse gleam@list:any(erlang:element(8, World), fun(Warehouse) ->
        (erlang:element(3, Warehouse) =:= Player_id) andalso (distance(erlang:element(4, Warehouse), {position, X, Y}) =< 300.0)
    end).

-file("src\\game_server.gleam", 425).
-spec all_positions(world()) -> list(position()).
all_positions(World) ->
    lists:append(gleam@list:map(erlang:element(6, World), fun(Item) ->
        erlang:element(4, Item)
    end), lists:append(gleam@list:map(erlang:element(7, World), fun(Item) ->
        erlang:element(4, Item)
    end), lists:append(gleam@list:map(erlang:element(8, World), fun(Item) ->
        erlang:element(4, Item)
    end), lists:append(gleam@list:map(erlang:element(9, World), fun(Item) ->
        erlang:element(4, Item)
    end), gleam@list:map(erlang:element(10, World), fun(Item) ->
        erlang:element(4, Item)
    end))))).

-file("src\\game_server.gleam", 421).
-spec too_close(world(), float(), float()) -> boolean().
too_close(World, X, Y) ->
    gleam@list:any(all_positions(World), fun(Position) ->
        distance(Position, {position, X, Y}) < 50.0
    end).

-file("src\\game_server.gleam", 393).
-spec terrain_buildable_cell(float(), float()) -> boolean().
terrain_buildable_cell(X, Y) ->
    Ax = gleam@float:absolute_value(X),
    Ay = gleam@float:absolute_value(Y),
    case (Ax =< 920.0) andalso (Ay =< 920.0) of
        false ->
            false;

        true ->
            Normalized = (game_server_os_ffi:terrain_height(X, Y) + 1.0) / 2.0,
            (Normalized >= 0.08) andalso (Normalized < 0.84)
    end.

-file("src\\game_server.gleam", 405).
-spec snap_position(float(), float()) -> position().
snap_position(X, Y) ->
    Cell_x = erlang:trunc((X + 1000.0) / 20.0),
    Cell_y = erlang:trunc((Y + 1000.0) / 20.0),
    Block_x = Cell_x - (Cell_x rem 2),
    Block_y = Cell_y - (Cell_y rem 2),
    {position, ((erlang:float(Block_x) + 1.0) * 20.0) - 1000.0, ((erlang:float(Block_y) + 1.0) * 20.0) - 1000.0}.

-file("src\\game_server.gleam", 385).
-spec terrain_buildable_footprint(float(), float()) -> boolean().
terrain_buildable_footprint(X, Y) ->
    {position, Sx, Sy} = snap_position(X, Y),
    ((terrain_buildable_cell(Sx - 10.0, Sy - 10.0) andalso terrain_buildable_cell(Sx + 10.0, Sy - 10.0)) andalso terrain_buildable_cell(Sx - 10.0, Sy + 10.0)) andalso terrain_buildable_cell(Sx + 10.0, Sy + 10.0).

-file("src\\game_server.gleam", 366).
-spec validate_position(world(), integer(), float(), float(), integer()) -> {ok, nil} | {error, binary()}.
validate_position(World, Player_id, X, Y, Cost) ->
    case player_authorized(World, Player_id) of
        false ->
            {error, ~"Player session is not valid."};

        true ->
            case validate_coordinate(X) andalso validate_coordinate(Y) of
                false ->
                    {error, ~"Invalid building position."};

                true ->
                    case player_money(World, Player_id) >= Cost of
                        false ->
                            {error, ~"Not enough money."};

                        true ->
                            case terrain_buildable_footprint(X, Y) of
                                false ->
                                    {error, ~"Buildings can only be placed on valid land."};

                                true ->
                                    case too_close(World, X, Y) of
                                        true ->
                                            {error, ~"Buildings must be at least 50 units apart."};

                                        false ->
                                            {ok, nil}
                                    end
                            end
                    end
            end
    end.

-file("src\\game_server.gleam", 277).
-spec build_structure(world(), integer(), server@messages:building_type(), float(), float()) -> {world(), {ok, nil} | {error, binary()}}.
build_structure(World, Player_id, Building, X, Y) ->
    Cost = server@messages:building_cost(Building),
    {position, Sx, Sy} = snap_position(X, Y),
    case validate_position(World, Player_id, Sx, Sy, Cost) of
        {error, Message} ->
            {World, {error, Message}};

        {ok, nil} ->
            Allowed = case Building of
                warehouse ->
                    warehouse_connected(World, Player_id, Sx, Sy);

                _ ->
                    inside_owned_city(World, Player_id, Sx, Sy)
            end,
            case Allowed of
                false ->
                    {World, {error, ~"Building placement is outside the player's allowed city/warehouse network."}};

                true ->
                    Id = erlang:element(3, World),
                    Position = {position, Sx, Sy},
                    World@1 = spend(World, Player_id, Cost),
                    World@2 = case Building of
                        gatherer ->
                            {world, erlang:element(2, World@1), Id + 1, erlang:element(4, World@1), erlang:element(5, World@1), erlang:element(6, World@1), erlang:element(7, World@1), erlang:element(8, World@1), [{simple_building, Id, Player_id, Position} | erlang:element(9, World@1)], erlang:element(10, World@1), erlang:element(11, World@1), erlang:element(12, World@1), erlang:element(13, World@1), erlang:element(14, World@1)};

                        factory ->
                            {world, erlang:element(2, World@1), Id + 1, erlang:element(4, World@1), erlang:element(5, World@1), erlang:element(6, World@1), [{factory, Id, Player_id, Position, 1, wood} | erlang:element(7, World@1)], erlang:element(8, World@1), erlang:element(9, World@1), erlang:element(10, World@1), erlang:element(11, World@1), erlang:element(12, World@1), erlang:element(13, World@1), erlang:element(14, World@1)};

                        farm ->
                            {world, erlang:element(2, World@1), Id + 1, erlang:element(4, World@1), erlang:element(5, World@1), erlang:element(6, World@1), erlang:element(7, World@1), erlang:element(8, World@1), erlang:element(9, World@1), [{simple_building, Id, Player_id, Position} | erlang:element(10, World@1)], erlang:element(11, World@1), erlang:element(12, World@1), erlang:element(13, World@1), erlang:element(14, World@1)};

                        warehouse ->
                            {world, erlang:element(2, World@1), Id + 1, erlang:element(4, World@1), erlang:element(5, World@1), erlang:element(6, World@1), erlang:element(7, World@1), [{warehouse, Id, Player_id, Position, 1000} | erlang:element(8, World@1)], erlang:element(9, World@1), erlang:element(10, World@1), erlang:element(11, World@1), erlang:element(12, World@1), erlang:element(13, World@1), erlang:element(14, World@1)}
                    end,
                    {World@2, {ok, nil}}
            end
    end.

-file("src\\game_server.gleam", 258).
-spec build_bank(world(), integer(), float(), float()) -> {world(), {ok, nil} | {error, binary()}}.
build_bank(World, Player_id, X, Y) ->
    {position, Sx, Sy} = snap_position(X, Y),
    case validate_position(World, Player_id, Sx, Sy, 10000) of
        {error, Message} ->
            {World, {error, Message}};

        {ok, nil} ->
            Owned = gleam@list:any(erlang:element(6, World), fun(Bank) ->
                erlang:element(3, Bank) =:= Player_id
            end),
            case Owned of
                true ->
                    {World, {error, ~"Only one Bank is allowed per player."}};

                false ->
                    Id = erlang:element(3, World),
                    Bank = {bank, Id, Player_id, {position, Sx, Sy}},
                    World@1 = spend(World, Player_id, 10000),
                    {{world, erlang:element(2, World@1), Id + 1, erlang:element(4, World@1), erlang:element(5, World@1), [Bank | erlang:element(6, World@1)], erlang:element(7, World@1), erlang:element(8, World@1), erlang:element(9, World@1), erlang:element(10, World@1), erlang:element(11, World@1), erlang:element(12, World@1), erlang:element(13, World@1), erlang:element(14, World@1)}, {ok, nil}}
            end
    end.

-file("src\\game_server.gleam", 469).
-spec remove_online(list(integer()), integer()) -> list(integer()).
remove_online(Ids, Player_id) ->
    gleam@list:filter(Ids, fun(Id) ->
        Id /= Player_id
    end).

-file("src\\game_server.gleam", 726).
-spec remove_player_from_session(world(), integer()) -> world().
remove_player_from_session(World, Player_id) ->
    {After_room, _} = leave_room(World, Player_id),
    {world, erlang:element(2, After_room), erlang:element(3, After_room), erlang:element(4, After_room), erlang:element(5, After_room), erlang:element(6, After_room), erlang:element(7, After_room), erlang:element(8, After_room), erlang:element(9, After_room), erlang:element(10, After_room), erlang:element(11, After_room), remove_online(erlang:element(12, After_room), Player_id), erlang:element(13, After_room), erlang:element(14, After_room)}.

-file("src\\game_server.gleam", 473).
-spec nickname_taken(world(), binary(), integer()) -> boolean().
nickname_taken(World, Nickname, Except_player_id) ->
    gleam@list:any(erlang:element(5, World), fun(Player) ->
        ((erlang:element(2, Player) /= Except_player_id) andalso is_online(World, erlang:element(2, Player))) andalso (string:lowercase(erlang:element(4, Player)) =:= string:lowercase(Nickname))
    end).

-file("src\\game_server.gleam", 481).
-spec valid_nickname(binary()) -> boolean().
valid_nickname(Nickname) ->
    Trimmed = gleam@string:trim(Nickname),
    Length = string:length(Trimmed),
    (Length >= 3) andalso (Length =< 24).

-file("src\\game_server.gleam", 451).
-spec find_player_by_uid(list(player()), binary()) -> gleam@option:option(integer()).
find_player_by_uid(Players, Uid) ->
    case Players of
        [] ->
            none;

        [Player | Rest] ->
            case erlang:element(3, Player) =:= Uid of
                true ->
                    {some, erlang:element(2, Player)};

                false ->
                    find_player_by_uid(Rest, Uid)
            end
    end.

-file("src\\game_server.gleam", 506).
-spec safe_name(binary()) -> binary().
safe_name(Name) ->
    case gleam@string:trim(Name) of
        ~"" ->
            ~"Player";

        Trimmed ->
            gleam@string:slice(Trimmed, 0, 32)
    end.

-file("src\\game_server.gleam", 104).
-spec handle(message(), world()) -> world().
handle(Message, World) ->
    case Message of
        {join_player, Auth_uid, Name, Auth_token, Reply_to} ->
            Nickname = safe_name(Name),
            case find_player_by_uid(erlang:element(5, World), Auth_uid) of
                {some, Id} ->
                    case is_online(World, Id) of
                        true ->
                            gleam@erlang@process:send(Reply_to, {error, ~"Player is already connected."}),
                            World;

                        false ->
                            case nickname_taken(World, Nickname, Id) of
                                true ->
                                    gleam@erlang@process:send(Reply_to, {error, ~"Nickname is already in use by an online player."}),
                                    World;

                                false ->
                                    gleam@erlang@process:send(Reply_to, {ok, Id}),
                                    Players = gleam@list:map(erlang:element(5, World), fun(Player) ->
                                        case erlang:element(2, Player) =:= Id of
                                            true ->
                                                {player, erlang:element(2, Player), erlang:element(3, Player), Nickname, Auth_token, erlang:element(6, Player), erlang:element(7, Player), erlang:element(8, Player), erlang:element(9, Player), erlang:element(10, Player), erlang:element(11, Player)};

                                            false ->
                                                Player
                                        end
                                    end),
                                    {world, erlang:element(2, World), erlang:element(3, World), erlang:element(4, World), Players, erlang:element(6, World), erlang:element(7, World), erlang:element(8, World), erlang:element(9, World), erlang:element(10, World), erlang:element(11, World), [Id | erlang:element(12, World)], erlang:element(13, World), erlang:element(14, World)}
                            end
                    end;

                none ->
                    case valid_nickname(Nickname) of
                        false ->
                            gleam@erlang@process:send(Reply_to, {error, ~"Nickname must be 3-24 characters."}),
                            World;

                        true ->
                            case nickname_taken(World, Nickname, 0) of
                                true ->
                                    gleam@erlang@process:send(Reply_to, {error, ~"Nickname is already in use by an online player."}),
                                    World;

                                false ->
                                    Player = {player, erlang:element(4, World), Auth_uid, Nickname, Auth_token, 100000, 0, 0, 0, 0, 0},
                                    gleam@erlang@process:send(Reply_to, {ok, erlang:element(2, Player)}),
                                    {world, erlang:element(2, World), erlang:element(3, World), erlang:element(4, World) + 1, [Player | erlang:element(5, World)], erlang:element(6, World), erlang:element(7, World), erlang:element(8, World), erlang:element(9, World), erlang:element(10, World), erlang:element(11, World), [erlang:element(2, Player) | erlang:element(12, World)], erlang:element(13, World), erlang:element(14, World)}
                            end
                    end
            end;

        {leave_player, Player_id} ->
            remove_player_from_session(World, Player_id);

        {build_bank, Player_id@1, X, Y, Reply_to@1} ->
            {New_world, Result} = build_bank(World, Player_id@1, X, Y),
            gleam@erlang@process:send(Reply_to@1, Result),
            New_world;

        {build_structure, Player_id@2, Building, X@1, Y@1, Reply_to@2} ->
            {New_world@1, Result@1} = build_structure(World, Player_id@2, Building, X@1, Y@1),
            gleam@erlang@process:send(Reply_to@2, Result@1),
            New_world@1;

        {spawn_vehicle, Player_id@3, X@2, Y@2, Tx, Ty, Speed, Reply_to@3} ->
            {New_world@2, Result@2} = spawn_vehicle(World, Player_id@3, X@2, Y@2, Tx, Ty, Speed),
            gleam@erlang@process:send(Reply_to@3, Result@2),
            New_world@2;

        {set_factory_product, Player_id@4, Factory_id, Product, Reply_to@4} ->
            {New_world@3, Result@3} = set_factory_product(World, Player_id@4, Factory_id, Product),
            gleam@erlang@process:send(Reply_to@4, Result@3),
            New_world@3;

        {create_room, Player_id@5, Mode, Reply_to@5} ->
            {New_world@4, Result@4} = create_room(World, Player_id@5, Mode),
            gleam@erlang@process:send(Reply_to@5, Result@4),
            New_world@4;

        {join_room, Player_id@6, Code, Reply_to@6} ->
            {New_world@5, Result@5} = join_room(World, Player_id@6, Code),
            gleam@erlang@process:send(Reply_to@6, Result@5),
            New_world@5;

        {start_room, Player_id@7, Reply_to@7} ->
            {New_world@6, Result@6} = start_room(World, Player_id@7),
            gleam@erlang@process:send(Reply_to@7, Result@6),
            New_world@6;

        {leave_room, Player_id@8, Reply_to@8} ->
            {New_world@7, Result@7} = leave_room(World, Player_id@8),
            gleam@erlang@process:send(Reply_to@8, Result@7),
            New_world@7;

        {get_lobby, Player_id@9, Reply_to@9} ->
            case lobby_json(World, Player_id@9) of
                {ok, Data} ->
                    gleam@erlang@process:send(Reply_to@9, {ok, Data});

                {error, Message@1} ->
                    gleam@erlang@process:send(Reply_to@9, {error, Message@1})
            end,
            World;

        {get_snapshot, Player_id@10, Reply_to@10} ->
            case snapshot_json(World, Player_id@10) of
                {ok, Snapshot} ->
                    gleam@erlang@process:send(Reply_to@10, {ok, Snapshot});

                {error, Message@2} ->
                    gleam@erlang@process:send(Reply_to@10, {error, Message@2})
            end,
            World
    end.

-file("src\\game_server.gleam", 96).
-spec loop(gleam@erlang@process:subject(message()), world()) -> nil.
loop(Subject, World) ->
    Next_world = case gleam@erlang@process:'receive'(Subject, 50) of
        {ok, Message} ->
            handle(Message, World);

        {error, nil} ->
            World
    end,
    loop(Subject, update(Next_world)).

-file("src\\game_server.gleam", 82).
-spec start() -> gleam@erlang@process:subject(message()).
start() ->
    Name = gleam_erlang_ffi:new_name(~"zelix_world"),
    _ = proc_lib:spawn_link(fun() ->
        Subject = gleam@erlang@process:named_subject(Name),
        _value = gleam_erlang_ffi:register_process(erlang:self(), Name),
        _value@1 = {ok, nil},
        case _value =:= _value@1 of
            true ->
                nil;

            false ->
                erlang:error(#{
                    gleam_error => assert,
                    message => ~"Assertion failed.",
                    file => ~"src\\game_server.gleam",
                    module => ~"game_server",
                    function => ~"start",
                    line => 86,
                    kind => binary_operator,
                    operator => '==',
                    left => #{
                        kind => expression,
                        value => _value,
                        start => 3092,
                        'end' => 3130
                    },
                    right => #{
                        kind => literal,
                        value => _value@1,
                        start => 3134,
                        'end' => 3141
                    },
                    start => 3085,
                    'end' => 3141,
                    expression_start => 3092
                })
        end,
        loop(Subject, initial_world())
    end),
    gleam@erlang@process:named_subject(Name).

-file("src\\game_server.gleam", 856).
-spec handle_test_factory(world(), float(), float()) -> world().
handle_test_factory(World, X, Y) ->
    Player = {player, 1, ~"test-uid", ~"test", ~"", 100000, 0, 0, 0, 0, 0},
    Room = {room, ~"TEST", 1, ~"multiplayer", [1], true},
    World@1 = {world, erlang:element(2, World), erlang:element(3, World), erlang:element(4, World), [Player], erlang:element(6, World), erlang:element(7, World), erlang:element(8, World), erlang:element(9, World), erlang:element(10, World), erlang:element(11, World), [1], [Room], erlang:element(14, World)},
    {World@2, _} = build_bank(World@1, 1, +0.0, +0.0),
    {World@3, _} = build_structure(World@2, 1, factory, X, Y),
    World@3.

