-module(game_server).
-compile([no_auto_import, nowarn_ignored, nowarn_unused_vars, nowarn_unused_function, nowarn_nomatch, inline]).
-export([initial_world/0, snapshot_json/2, start/0, handle_test_factory/3]).
-export_type([position/0, player/0, bank/0, factory/0, warehouse/0, simple_building/0, vehicle/0, world/0, message/0]).

-type position() :: {position, float(), float()}.

-type player() :: {player, integer(), binary(), binary(), integer()}.

-type bank() :: {bank, integer(), integer(), position()}.

-type factory() :: {factory, integer(), integer(), position(), integer(), server@messages:product_type()}.

-type warehouse() :: {warehouse, integer(), integer(), position(), integer()}.

-type simple_building() :: {simple_building, integer(), integer(), position()}.

-type vehicle() :: {vehicle, integer(), integer(), position(), position(), float()}.

-type world() :: {world, integer(), integer(), integer(), list(player()), list(bank()), list(factory()), list(warehouse()), list(simple_building()), list(simple_building()), list(vehicle()), list(integer())}.

-type message() :: {join_player, binary(), binary(), gleam@erlang@process:subject({ok, integer()} | {error, binary()})} | {leave_player, integer()} | {build_bank, integer(), float(), float(), gleam@erlang@process:subject({ok, nil} | {error, binary()})} | {build_structure, integer(), server@messages:building_type(), float(), float(), gleam@erlang@process:subject({ok, nil} | {error, binary()})} | {spawn_vehicle, integer(), float(), float(), float(), float(), float(), gleam@erlang@process:subject({ok, nil} | {error, binary()})} | {set_factory_product, integer(), integer(), server@messages:product_type(), gleam@erlang@process:subject({ok, nil} | {error, binary()})} | {get_snapshot, integer(), gleam@erlang@process:subject({ok, binary()} | {error, binary()})}.

-file("src\\game_server.gleam", 65).
-spec initial_world() -> world().
initial_world() ->
    {world, 0, 1, 1, [], [], [], [], [], [], [], []}.

-file("src\\game_server.gleam", 171).
-spec produce_for_player(player(), list(factory())) -> player().
produce_for_player(Player, Factories) ->
    Count = gleam@list:fold(Factories, 0, fun(Total, Factory) ->
        case erlang:element(3, Factory) =:= erlang:element(2, Player) of
            true ->
                Total + (server@messages:product_value(erlang:element(6, Factory)) * erlang:element(5, Factory));

            false ->
                Total
        end
    end),
    {player, erlang:element(2, Player), erlang:element(3, Player), erlang:element(4, Player), erlang:element(5, Player) + Count}.

-file("src\\game_server.gleam", 364).
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

-file("src\\game_server.gleam", 431).
-spec move_vehicle(vehicle()) -> vehicle().
move_vehicle(Vehicle) ->
    {position, X, Y} = erlang:element(4, Vehicle),
    {position, Tx, Ty} = erlang:element(5, Vehicle),
    Dx = Tx - X,
    Dy = Ty - Y,
    D = distance(erlang:element(4, Vehicle), erlang:element(5, Vehicle)),
    case (D =< erlang:element(6, Vehicle)) orelse (D =< 0.001) of
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
            end * erlang:element(6, Vehicle)), Y + (case D of
                +0.0 ->
                    +0.0;

                -0.0 ->
                    -0.0;

                _value@1 ->
                    Dy / _value@1
            end * erlang:element(6, Vehicle))}, erlang:element(5, Vehicle), erlang:element(6, Vehicle)}
    end.

-file("src\\game_server.gleam", 160).
-spec update(world()) -> world().
update(World) ->
    Next_tick = erlang:element(2, World) + 1,
    Vehicles = gleam@list:map(erlang:element(11, World), fun move_vehicle/1),
    Players = case (Next_tick rem 5) =:= 0 of
        true ->
            gleam@list:map(erlang:element(5, World), fun(Player) ->
                produce_for_player(Player, erlang:element(7, World))
            end);

        false ->
            erlang:element(5, World)
    end,
    {world, Next_tick, erlang:element(3, World), erlang:element(4, World), Players, erlang:element(6, World), erlang:element(7, World), erlang:element(8, World), erlang:element(9, World), erlang:element(10, World), Vehicles, erlang:element(12, World)}.

-file("src\\game_server.gleam", 480).
-spec vehicle_json(vehicle()) -> gleam@json:json().
vehicle_json(Vehicle) ->
    {position, X, Y} = erlang:element(4, Vehicle),
    {position, Tx, Ty} = erlang:element(5, Vehicle),
    gleam@json:object([{~"id", gleam@json:int(erlang:element(2, Vehicle))}, {~"owner_id", gleam@json:int(erlang:element(3, Vehicle))}, {~"x", gleam@json:float(X)}, {~"y", gleam@json:float(Y)}, {~"target_x", gleam@json:float(Tx)}, {~"target_y", gleam@json:float(Ty)}, {~"speed", gleam@json:float(erlang:element(6, Vehicle))}]).

-file("src\\game_server.gleam", 476).
-spec simple_json(simple_building()) -> gleam@json:json().
simple_json(Building) ->
    {position, X, Y} = erlang:element(4, Building),
    gleam@json:object([{~"id", gleam@json:int(erlang:element(2, Building))}, {~"owner_id", gleam@json:int(erlang:element(3, Building))}, {~"x", gleam@json:float(X)}, {~"y", gleam@json:float(Y)}]).

-file("src\\game_server.gleam", 472).
-spec warehouse_json(warehouse()) -> gleam@json:json().
warehouse_json(Warehouse) ->
    {position, X, Y} = erlang:element(4, Warehouse),
    gleam@json:object([{~"id", gleam@json:int(erlang:element(2, Warehouse))}, {~"owner_id", gleam@json:int(erlang:element(3, Warehouse))}, {~"x", gleam@json:float(X)}, {~"y", gleam@json:float(Y)}, {~"capacity", gleam@json:int(erlang:element(5, Warehouse))}]).

-file("src\\game_server.gleam", 468).
-spec factory_json(factory()) -> gleam@json:json().
factory_json(Factory) ->
    {position, X, Y} = erlang:element(4, Factory),
    gleam@json:object([{~"id", gleam@json:int(erlang:element(2, Factory))}, {~"owner_id", gleam@json:int(erlang:element(3, Factory))}, {~"x", gleam@json:float(X)}, {~"y", gleam@json:float(Y)}, {~"level", gleam@json:int(erlang:element(5, Factory))}, {~"product", server@messages:product_json(erlang:element(6, Factory))}]).

-file("src\\game_server.gleam", 464).
-spec bank_json(bank()) -> gleam@json:json().
bank_json(Bank) ->
    {position, X, Y} = erlang:element(4, Bank),
    gleam@json:object([{~"id", gleam@json:int(erlang:element(2, Bank))}, {~"owner_id", gleam@json:int(erlang:element(3, Bank))}, {~"x", gleam@json:float(X)}, {~"y", gleam@json:float(Y)}]).

-file("src\\game_server.gleam", 405).
-spec player_money(world(), integer()) -> integer().
player_money(World, Player_id) ->
    gleam@list:fold(erlang:element(5, World), 0, fun(Money, Player) ->
        case erlang:element(2, Player) =:= Player_id of
            true ->
                erlang:element(5, Player);

            false ->
                Money
        end
    end).

-file("src\\game_server.gleam", 385).
-spec is_online(world(), integer()) -> boolean().
is_online(World, Player_id) ->
    gleam@list:any(erlang:element(12, World), fun(Id) ->
        Id =:= Player_id
    end).

-file("src\\game_server.gleam", 383).
-spec player_exists(world(), integer()) -> boolean().
player_exists(World, Player_id) ->
    gleam@list:any(erlang:element(5, World), fun(Player) ->
        erlang:element(2, Player) =:= Player_id
    end).

-file("src\\game_server.gleam", 387).
-spec player_authorized(world(), integer()) -> boolean().
player_authorized(World, Player_id) ->
    player_exists(World, Player_id) andalso is_online(World, Player_id).

-file("src\\game_server.gleam", 443).
-spec snapshot_json(world(), integer()) -> {ok, binary()} | {error, binary()}.
snapshot_json(World, Player_id) ->
    case player_authorized(World, Player_id) of
        false ->
            {error, ~"Player session is not valid."};

        true ->
            Money = player_money(World, Player_id),
            Data = gleam@json:object([{~"tick", gleam@json:int(erlang:element(2, World))}, {~"money", gleam@json:int(Money)}, {~"banks", gleam@json:array(erlang:element(6, World), fun bank_json/1)}, {~"factories", gleam@json:array(erlang:element(7, World), fun factory_json/1)}, {~"warehouses", gleam@json:array(erlang:element(8, World), fun warehouse_json/1)}, {~"gatherers", gleam@json:array(erlang:element(9, World), fun simple_json/1)}, {~"farms", gleam@json:array(erlang:element(10, World), fun simple_json/1)}, {~"vehicles", gleam@json:array(erlang:element(11, World), fun vehicle_json/1)}]),
            Envelope = gleam@json:object([{~"type", gleam@json:string(~"world_snapshot")}, {~"data", Data}]),
            {ok, begin
                _pipe = Envelope,
                gleam@json:to_string(_pipe)
            end}
    end.

-file("src\\game_server.gleam", 273).
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
            {{world, erlang:element(2, World), erlang:element(3, World), erlang:element(4, World), erlang:element(5, World), erlang:element(6, World), Factories, erlang:element(8, World), erlang:element(9, World), erlang:element(10, World), erlang:element(11, World), erlang:element(12, World)}, {ok, nil}}
    end.

-file("src\\game_server.gleam", 269).
-spec same_position(position(), position()) -> boolean().
same_position(A, B) ->
    distance(A, B) =< 1.0.

-file("src\\game_server.gleam", 260).
-spec owned_destination_at(world(), integer(), float(), float()) -> boolean().
owned_destination_at(World, Player_id, X, Y) ->
    gleam@list:any(erlang:element(7, World), fun(Factory) ->
        (erlang:element(3, Factory) =:= Player_id) andalso same_position(erlang:element(4, Factory), {position, X, Y})
    end) orelse gleam@list:any(erlang:element(8, World), fun(Warehouse) ->
        (erlang:element(3, Warehouse) =:= Player_id) andalso same_position(erlang:element(4, Warehouse), {position, X, Y})
    end).

-file("src\\game_server.gleam", 254).
-spec owned_factory_at(world(), integer(), float(), float()) -> boolean().
owned_factory_at(World, Player_id, X, Y) ->
    gleam@list:any(erlang:element(7, World), fun(Factory) ->
        (erlang:element(3, Factory) =:= Player_id) andalso same_position(erlang:element(4, Factory), {position, X, Y})
    end).

-file("src\\game_server.gleam", 339).
-spec validate_coordinate(float()) -> boolean().
validate_coordinate(Value) ->
    (Value >= (+0.0 - 1000.0)) andalso (Value =< 1000.0).

-file("src\\game_server.gleam", 234).
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
                                    {{world, erlang:element(2, World), Id + 1, erlang:element(4, World), erlang:element(5, World), erlang:element(6, World), erlang:element(7, World), erlang:element(8, World), erlang:element(9, World), erlang:element(10, World), [Vehicle | erlang:element(11, World)], erlang:element(12, World)}, {ok, nil}}
                            end
                    end
            end
    end.

-file("src\\game_server.gleam", 414).
-spec spend(world(), integer(), integer()) -> world().
spend(World, Player_id, Amount) ->
    Players = gleam@list:map(erlang:element(5, World), fun(Player) ->
        case erlang:element(2, Player) =:= Player_id of
            true ->
                {player, erlang:element(2, Player), erlang:element(3, Player), erlang:element(4, Player), erlang:element(5, Player) - Amount};

            false ->
                Player
        end
    end),
    {world, erlang:element(2, World), erlang:element(3, World), erlang:element(4, World), Players, erlang:element(6, World), erlang:element(7, World), erlang:element(8, World), erlang:element(9, World), erlang:element(10, World), erlang:element(11, World), erlang:element(12, World)}.

-file("src\\game_server.gleam", 360).
-spec inside_owned_city(world(), integer(), float(), float()) -> boolean().
inside_owned_city(World, Player_id, X, Y) ->
    gleam@list:any(erlang:element(6, World), fun(Bank) ->
        (erlang:element(3, Bank) =:= Player_id) andalso (distance(erlang:element(4, Bank), {position, X, Y}) =< 300.0)
    end).

-file("src\\game_server.gleam", 229).
-spec warehouse_connected(world(), integer(), float(), float()) -> boolean().
warehouse_connected(World, Player_id, X, Y) ->
    gleam@list:any(erlang:element(6, World), fun(Bank) ->
        (erlang:element(3, Bank) =:= Player_id) andalso (distance(erlang:element(4, Bank), {position, X, Y}) =< 300.0)
    end) orelse gleam@list:any(erlang:element(8, World), fun(Warehouse) ->
        (erlang:element(3, Warehouse) =:= Player_id) andalso (distance(erlang:element(4, Warehouse), {position, X, Y}) =< 300.0)
    end).

-file("src\\game_server.gleam", 347).
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

-file("src\\game_server.gleam", 343).
-spec too_close(world(), float(), float()) -> boolean().
too_close(World, X, Y) ->
    gleam@list:any(all_positions(World), fun(Position) ->
        distance(Position, {position, X, Y}) < 50.0
    end).

-file("src\\game_server.gleam", 316).
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

-file("src\\game_server.gleam", 328).
-spec snap_position(float(), float()) -> position().
snap_position(X, Y) ->
    Cell_x = erlang:trunc((X + 1000.0) / 20.0),
    Cell_y = erlang:trunc((Y + 1000.0) / 20.0),
    Block_x = Cell_x - (Cell_x rem 2),
    Block_y = Cell_y - (Cell_y rem 2),
    {position, ((erlang:float(Block_x) + 1.0) * 20.0) - 1000.0, ((erlang:float(Block_y) + 1.0) * 20.0) - 1000.0}.

-file("src\\game_server.gleam", 308).
-spec terrain_buildable_footprint(float(), float()) -> boolean().
terrain_buildable_footprint(X, Y) ->
    {position, Sx, Sy} = snap_position(X, Y),
    ((terrain_buildable_cell(Sx - 10.0, Sy - 10.0) andalso terrain_buildable_cell(Sx + 10.0, Sy - 10.0)) andalso terrain_buildable_cell(Sx - 10.0, Sy + 10.0)) andalso terrain_buildable_cell(Sx + 10.0, Sy + 10.0).

-file("src\\game_server.gleam", 289).
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

-file("src\\game_server.gleam", 200).
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
                            {world, erlang:element(2, World@1), Id + 1, erlang:element(4, World@1), erlang:element(5, World@1), erlang:element(6, World@1), erlang:element(7, World@1), erlang:element(8, World@1), [{simple_building, Id, Player_id, Position} | erlang:element(9, World@1)], erlang:element(10, World@1), erlang:element(11, World@1), erlang:element(12, World@1)};

                        factory ->
                            {world, erlang:element(2, World@1), Id + 1, erlang:element(4, World@1), erlang:element(5, World@1), erlang:element(6, World@1), [{factory, Id, Player_id, Position, 1, wood} | erlang:element(7, World@1)], erlang:element(8, World@1), erlang:element(9, World@1), erlang:element(10, World@1), erlang:element(11, World@1), erlang:element(12, World@1)};

                        farm ->
                            {world, erlang:element(2, World@1), Id + 1, erlang:element(4, World@1), erlang:element(5, World@1), erlang:element(6, World@1), erlang:element(7, World@1), erlang:element(8, World@1), erlang:element(9, World@1), [{simple_building, Id, Player_id, Position} | erlang:element(10, World@1)], erlang:element(11, World@1), erlang:element(12, World@1)};

                        warehouse ->
                            {world, erlang:element(2, World@1), Id + 1, erlang:element(4, World@1), erlang:element(5, World@1), erlang:element(6, World@1), erlang:element(7, World@1), [{warehouse, Id, Player_id, Position, 1000} | erlang:element(8, World@1)], erlang:element(9, World@1), erlang:element(10, World@1), erlang:element(11, World@1), erlang:element(12, World@1)}
                    end,
                    {World@2, {ok, nil}}
            end
    end.

-file("src\\game_server.gleam", 181).
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
                    {{world, erlang:element(2, World@1), Id + 1, erlang:element(4, World@1), erlang:element(5, World@1), [Bank | erlang:element(6, World@1)], erlang:element(7, World@1), erlang:element(8, World@1), erlang:element(9, World@1), erlang:element(10, World@1), erlang:element(11, World@1), erlang:element(12, World@1)}, {ok, nil}}
            end
    end.

-file("src\\game_server.gleam", 389).
-spec remove_online(list(integer()), integer()) -> list(integer()).
remove_online(Ids, Player_id) ->
    gleam@list:filter(Ids, fun(Id) ->
        Id /= Player_id
    end).

-file("src\\game_server.gleam", 393).
-spec nickname_taken(world(), binary(), integer()) -> boolean().
nickname_taken(World, Nickname, Except_player_id) ->
    gleam@list:any(erlang:element(5, World), fun(Player) ->
        ((erlang:element(2, Player) /= Except_player_id) andalso is_online(World, erlang:element(2, Player))) andalso (string:lowercase(erlang:element(4, Player)) =:= string:lowercase(Nickname))
    end).

-file("src\\game_server.gleam", 399).
-spec valid_nickname(binary()) -> boolean().
valid_nickname(Nickname) ->
    Trimmed = gleam@string:trim(Nickname),
    Length = string:length(Trimmed),
    (Length >= 3) andalso (Length =< 24).

-file("src\\game_server.gleam", 373).
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

-file("src\\game_server.gleam", 424).
-spec safe_name(binary()) -> binary().
safe_name(Name) ->
    case gleam@string:trim(Name) of
        ~"" ->
            ~"Player";

        Trimmed ->
            gleam@string:slice(Trimmed, 0, 32)
    end.

-file("src\\game_server.gleam", 76).
-spec handle(message(), world()) -> world().
handle(Message, World) ->
    case Message of
        {join_player, Auth_uid, Name, Reply_to} ->
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
                                    {world, erlang:element(2, World), erlang:element(3, World), erlang:element(4, World), erlang:element(5, World), erlang:element(6, World), erlang:element(7, World), erlang:element(8, World), erlang:element(9, World), erlang:element(10, World), erlang:element(11, World), [Id | erlang:element(12, World)]}
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
                                    Player = {player, erlang:element(4, World), Auth_uid, Nickname, 100000},
                                    gleam@erlang@process:send(Reply_to, {ok, erlang:element(2, Player)}),
                                    {world, erlang:element(2, World), erlang:element(3, World), erlang:element(4, World) + 1, [Player | erlang:element(5, World)], erlang:element(6, World), erlang:element(7, World), erlang:element(8, World), erlang:element(9, World), erlang:element(10, World), erlang:element(11, World), [erlang:element(2, Player) | erlang:element(12, World)]}
                            end
                    end
            end;

        {leave_player, Player_id} ->
            {world, erlang:element(2, World), erlang:element(3, World), erlang:element(4, World), erlang:element(5, World), erlang:element(6, World), erlang:element(7, World), erlang:element(8, World), erlang:element(9, World), erlang:element(10, World), erlang:element(11, World), remove_online(erlang:element(12, World), Player_id)};

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

        {get_snapshot, Player_id@5, Reply_to@5} ->
            case snapshot_json(World, Player_id@5) of
                {ok, Snapshot} ->
                    gleam@erlang@process:send(Reply_to@5, {ok, Snapshot});

                {error, Message@1} ->
                    gleam@erlang@process:send(Reply_to@5, {error, Message@1})
            end,
            World
    end.

-file("src\\game_server.gleam", 69).
-spec loop(gleam@erlang@process:subject(message()), world()) -> nil.
loop(Subject, World) ->
    case gleam@erlang@process:'receive'(Subject, 1000) of
        {ok, Message} ->
            loop(Subject, handle(Message, World));

        {error, nil} ->
            loop(Subject, update(World))
    end.

-file("src\\game_server.gleam", 55).
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
                    line => 59,
                    kind => binary_operator,
                    operator => '==',
                    left => #{
                        kind => expression,
                        value => _value,
                        start => 2297,
                        'end' => 2335
                    },
                    right => #{
                        kind => literal,
                        value => _value@1,
                        start => 2339,
                        'end' => 2346
                    },
                    start => 2290,
                    'end' => 2346,
                    expression_start => 2297
                })
        end,
        loop(Subject, initial_world())
    end),
    gleam@erlang@process:named_subject(Name).

-file("src\\game_server.gleam", 486).
-spec handle_test_factory(world(), float(), float()) -> world().
handle_test_factory(World, X, Y) ->
    Player = {player, 1, ~"test-uid", ~"test", 100000},
    World@1 = {world, erlang:element(2, World), erlang:element(3, World), erlang:element(4, World), [Player], erlang:element(6, World), erlang:element(7, World), erlang:element(8, World), erlang:element(9, World), erlang:element(10, World), erlang:element(11, World), [1]},
    {World@2, _} = build_bank(World@1, 1, +0.0, +0.0),
    {World@3, _} = build_structure(World@2, 1, factory, X, Y),
    World@3.

