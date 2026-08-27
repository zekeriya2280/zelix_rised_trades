import gleam/float
import gleam/json
import gleam/int
import gleam/list
import gleam/option
import gleam/string
import gleam/erlang/process
import server/firestore
import server/messages

pub type Position { Position(x: Float, y: Float) }

pub type Player {
  Player(
    id: Int,
    auth_uid: String,
    name: String,
    auth_token: String,
    money: Int,
    wood: Int,
    stone: Int,
    iron: Int,
    gold: Int,
    grain: Int,
  )
}
pub type Bank { Bank(id: Int, owner_id: Int, position: Position) }
pub type Factory { Factory(id: Int, owner_id: Int, position: Position, level: Int, product: messages.ProductType) }
pub type Warehouse { Warehouse(id: Int, owner_id: Int, position: Position, capacity: Int) }
pub type SimpleBuilding { SimpleBuilding(id: Int, owner_id: Int, position: Position) }
pub type Vehicle { Vehicle(id: Int, owner_id: Int, position: Position, target: Position, speed: Float) }

pub type Room {
  Room(id: String, host_id: Int, mode: String, players: List(Int), started: Bool)
}

pub type World {
  World(
    tick: Int,
    next_id: Int,
    next_player_id: Int,
    players: List(Player),
    banks: List(Bank),
    factories: List(Factory),
    warehouses: List(Warehouse),
    gatherers: List(SimpleBuilding),
    farms: List(SimpleBuilding),
    vehicles: List(Vehicle),
    online_players: List(Int),
    rooms: List(Room),
    next_room_id: Int,
  )
}

pub type Message {
  JoinPlayer(auth_uid: String, name: String, auth_token: String, reply_to: process.Subject(Result(Int, String)))
  LeavePlayer(player_id: Int)
  BuildBank(player_id: Int, x: Float, y: Float, reply_to: process.Subject(Result(Nil, String)))
  BuildStructure(player_id: Int, building: messages.BuildingType, x: Float, y: Float, reply_to: process.Subject(Result(Nil, String)))
  SpawnVehicle(player_id: Int, x: Float, y: Float, target_x: Float, target_y: Float, speed: Float, reply_to: process.Subject(Result(Nil, String)))
  SetFactoryProduct(player_id: Int, factory_id: Int, product: messages.ProductType, reply_to: process.Subject(Result(Nil, String)))
  CreateRoom(player_id: Int, mode: String, reply_to: process.Subject(Result(String, String)))
  JoinRoom(player_id: Int, code: String, reply_to: process.Subject(Result(String, String)))
  StartRoom(player_id: Int, reply_to: process.Subject(Result(Nil, String)))
  LeaveRoom(player_id: Int, reply_to: process.Subject(Result(Nil, String)))
  GetLobby(player_id: Int, reply_to: process.Subject(Result(String, String)))
  GetSnapshot(player_id: Int, reply_to: process.Subject(Result(String, String)))
}

const starting_money = 100000
const bank_cost = 10000
const city_radius = 300.0
const minimum_distance = 50.0
const vehicle_speed_max = 500.0
const world_limit = 1000.0
const room_max_players = 5
const production_interval_ticks = 20

@external(erlang, "game_server_os_ffi", "terrain_height")
fn terrain_height(x: Float, y: Float) -> Float

pub fn start() -> process.Subject(Message) {
  let name = process.new_name("zelix_world")
  let _pid = process.spawn(fn() -> Nil {
    let subject = process.named_subject(name)
    assert process.register(process.self(), name) == Ok(Nil)
    loop(subject, initial_world())
  })
  process.named_subject(name)
}

pub fn initial_world() -> World {
  World(0, 1, 1, [], [], [], [], [], [], [], [], [], 1)
}

fn loop(subject: process.Subject(Message), world: World) -> Nil {
  let next_world = case process.receive(subject, within: 50) {
    Ok(message) -> handle(message, world)
    Error(Nil) -> world
  }
  loop(subject, update(next_world))
}

fn handle(message: Message, world: World) -> World {
  case message {
    JoinPlayer(auth_uid, name, auth_token, reply_to) -> {
      let nickname = safe_name(name)
      case find_player_by_uid(world.players, auth_uid) {
        option.Some(id) -> {
          case is_online(world, id) {
            True -> {
              process.send(reply_to, Error("Player is already connected."))
              world
            }
            False -> {
              case nickname_taken(world, nickname, id) {
                True -> {
                  process.send(reply_to, Error("Nickname is already in use by an online player."))
                  world
                }
                False -> {
                  process.send(reply_to, Ok(id))
                  let players = list.map(world.players, fn(player) {
                    case player.id == id {
                      True -> Player(..player, name: nickname, auth_token: auth_token)
                      False -> player
                    }
                  })
                  World(..world, players: players, online_players: [id, ..world.online_players])
                }
              }
            }
          }
        }
        option.None -> {
          case valid_nickname(nickname) {
            False -> {
              process.send(reply_to, Error("Nickname must be 3-24 characters."))
              world
            }
            True -> case nickname_taken(world, nickname, 0) {
              True -> {
                process.send(reply_to, Error("Nickname is already in use by an online player."))
                world
              }
              False -> {
                let player = Player(
                  world.next_player_id,
                  auth_uid,
                  nickname,
                  auth_token,
                  starting_money,
                  0,
                  0,
                  0,
                  0,
                  0,
                )
                process.send(reply_to, Ok(player.id))
                World(
                  ..world,
                  next_player_id: world.next_player_id + 1,
                  players: [player, ..world.players],
                  online_players: [player.id, ..world.online_players],
                )
              }
            }
          }
        }
      }
    }
    LeavePlayer(player_id) -> remove_player_from_session(world, player_id)
    BuildBank(player_id, x, y, reply_to) -> {
      let #(new_world, result) = build_bank(world, player_id, x, y)
      process.send(reply_to, result)
      new_world
    }
    BuildStructure(player_id, building, x, y, reply_to) -> {
      let #(new_world, result) = build_structure(world, player_id, building, x, y)
      process.send(reply_to, result)
      new_world
    }
    SpawnVehicle(player_id, x, y, tx, ty, speed, reply_to) -> {
      let #(new_world, result) = spawn_vehicle(world, player_id, x, y, tx, ty, speed)
      process.send(reply_to, result)
      new_world
    }
    SetFactoryProduct(player_id, factory_id, product, reply_to) -> {
      let #(new_world, result) = set_factory_product(world, player_id, factory_id, product)
      process.send(reply_to, result)
      new_world
    }
    CreateRoom(player_id, mode, reply_to) -> {
      let #(new_world, result) = create_room(world, player_id, mode)
      process.send(reply_to, result)
      new_world
    }
    JoinRoom(player_id, code, reply_to) -> {
      let #(new_world, result) = join_room(world, player_id, code)
      process.send(reply_to, result)
      new_world
    }
    StartRoom(player_id, reply_to) -> {
      let #(new_world, result) = start_room(world, player_id)
      process.send(reply_to, result)
      new_world
    }
    LeaveRoom(player_id, reply_to) -> {
      let #(new_world, result) = leave_room(world, player_id)
      process.send(reply_to, result)
      new_world
    }
    GetLobby(player_id, reply_to) -> {
      case lobby_json(world, player_id) {
        Ok(data) -> process.send(reply_to, Ok(data))
        Error(message) -> process.send(reply_to, Error(message))
      }
      world
    }
    GetSnapshot(player_id, reply_to) -> {
      case snapshot_json(world, player_id) {
        Ok(snapshot) -> process.send(reply_to, Ok(snapshot))
        Error(message) -> process.send(reply_to, Error(message))
      }
      world
    }
  }
}

fn update(world: World) -> World {
  let next_tick = world.tick + 1
  let vehicles = list.map(world.vehicles, move_vehicle)
  let players =
    case next_tick % production_interval_ticks == 0 {
      True -> list.map(world.players, fn(player) { produce_for_player(player, world.factories, world.warehouses) })
      False -> world.players
    }
  World(..world, tick: next_tick, players: players, vehicles: vehicles)
}

fn produce_for_player(player: Player, factories: List(Factory), warehouses: List(Warehouse)) -> Player {
  let capacity = list.fold(warehouses, 0, fn(total, warehouse) {
    case warehouse.owner_id == player.id { True -> total + warehouse.capacity False -> total }
  })
  let used = inventory_total(player)
  let room = positive_or_zero(capacity - used)
  case room == 0 {
    True -> player
    False -> list.fold(factories, player, fn(current, factory) {
      case factory.owner_id == player.id {
        False -> current
        True -> add_product_capped(current, factory.product, factory.level, capacity)
      }
    })
  }
}

fn build_bank(world: World, player_id: Int, x: Float, y: Float) -> #(World, Result(Nil, String)) {
  let Position(sx, sy) = snap_position(x, y)
  case validate_position(world, player_id, sx, sy, bank_cost) {
    Error(message) -> #(world, Error(message))
    Ok(Nil) -> {
      let owned = list.any(world.banks, fn(bank) { bank.owner_id == player_id })
      case owned {
        True -> #(world, Error("Only one Bank is allowed per player."))
        False -> {
          let id = world.next_id
          let bank = Bank(id, player_id, Position(sx, sy))
          let world = spend(world, player_id, bank_cost)
          #(World(..world, next_id: id + 1, banks: [bank, ..world.banks]), Ok(Nil))
        }
      }
    }
  }
}

fn build_structure(world: World, player_id: Int, building: messages.BuildingType, x: Float, y: Float) -> #(World, Result(Nil, String)) {
  let cost = messages.building_cost(building)
  let Position(sx, sy) = snap_position(x, y)
  case validate_position(world, player_id, sx, sy, cost) {
    Error(message) -> #(world, Error(message))
    Ok(Nil) -> {
      let allowed = case building {
        messages.Warehouse -> warehouse_connected(world, player_id, sx, sy)
        _ -> inside_owned_city(world, player_id, sx, sy)
      }
      case allowed {
        False -> #(world, Error("Building placement is outside the player's allowed city/warehouse network."))
        True -> {
          let id = world.next_id
          let position = Position(sx, sy)
          let world = spend(world, player_id, cost)
          let world = case building {
            messages.Gatherer -> World(..world, next_id: id + 1, gatherers: [SimpleBuilding(id, player_id, position), ..world.gatherers])
            messages.Factory -> World(..world, next_id: id + 1, factories: [Factory(id, player_id, position, 1, messages.Wood), ..world.factories])
            messages.Farm -> World(..world, next_id: id + 1, farms: [SimpleBuilding(id, player_id, position), ..world.farms])
            messages.Warehouse -> World(..world, next_id: id + 1, warehouses: [Warehouse(id, player_id, position, 1000), ..world.warehouses])
          }
          #(world, Ok(Nil))
        }
      }
    }
  }
}

fn warehouse_connected(world: World, player_id: Int, x: Float, y: Float) -> Bool {
  list.any(world.banks, fn(bank) { bank.owner_id == player_id && distance(bank.position, Position(x, y)) <=. city_radius })
  || list.any(world.warehouses, fn(warehouse) { warehouse.owner_id == player_id && distance(warehouse.position, Position(x, y)) <=. city_radius })
}

fn spawn_vehicle(world: World, player_id: Int, x: Float, y: Float, tx: Float, ty: Float, speed: Float) -> #(World, Result(Nil, String)) {
  case player_authorized(world, player_id) && validate_coordinate(x) && validate_coordinate(y) && validate_coordinate(tx) && validate_coordinate(ty) {
    False -> #(world, Error("Invalid vehicle position or player session."))
    True -> case speed >. 0.0 && speed <=. vehicle_speed_max {
      False -> #(world, Error("Invalid vehicle speed."))
      True -> case owned_factory_at(world, player_id, x, y) {
        False -> #(world, Error("Vehicle source must be one of your factories."))
        True -> case owned_destination_at(world, player_id, tx, ty) {
          False -> #(world, Error("Vehicle target must be one of your factories or warehouses."))
          True -> {
            let id = world.next_id
            let vehicle = Vehicle(id, player_id, Position(x, y), Position(tx, ty), speed)
            #(World(..world, next_id: id + 1, vehicles: [vehicle, ..world.vehicles]), Ok(Nil))
          }
        }
      }
    }
  }
}

fn owned_factory_at(world: World, player_id: Int, x: Float, y: Float) -> Bool {
  list.any(world.factories, fn(factory) {
    factory.owner_id == player_id && same_position(factory.position, Position(x, y))
  })
}

fn owned_destination_at(world: World, player_id: Int, x: Float, y: Float) -> Bool {
  list.any(world.factories, fn(factory) {
    factory.owner_id == player_id && same_position(factory.position, Position(x, y))
  })
  || list.any(world.warehouses, fn(warehouse) {
    warehouse.owner_id == player_id && same_position(warehouse.position, Position(x, y))
  })
}

fn same_position(a: Position, b: Position) -> Bool {
  distance(a, b) <=. 1.0
}

fn set_factory_product(world: World, player_id: Int, factory_id: Int, product: messages.ProductType) -> #(World, Result(Nil, String)) {
  let found = list.any(world.factories, fn(factory) { factory.id == factory_id && factory.owner_id == player_id })
  case found {
    False -> #(world, Error("Factory not found or not owned by player."))
    True -> {
      let factories = list.map(world.factories, fn(factory) {
        case factory.id == factory_id && factory.owner_id == player_id {
          True -> Factory(..factory, product: product)
          False -> factory
        }
      })
      #(World(..world, factories: factories), Ok(Nil))
    }
  }
}

fn validate_position(world: World, player_id: Int, x: Float, y: Float, cost: Int) -> Result(Nil, String) {
  case player_authorized(world, player_id) {
    False -> Error("Player session is not valid.")
    True -> case validate_coordinate(x) && validate_coordinate(y) {
      False -> Error("Invalid building position.")
      True -> case player_money(world, player_id) >= cost {
        False -> Error("Not enough money.")
        True -> case terrain_buildable_footprint(x, y) {
          False -> Error("Buildings can only be placed on valid land.")
          True -> case too_close(world, x, y) {
            True -> Error("Buildings must be at least 50 units apart.")
            False -> Ok(Nil)
          }
        }
      }
    }
  }
}

fn terrain_buildable_footprint(x: Float, y: Float) -> Bool {
  let Position(sx, sy) = snap_position(x, y)
  terrain_buildable_cell(sx -. 10.0, sy -. 10.0)
    && terrain_buildable_cell(sx +. 10.0, sy -. 10.0)
    && terrain_buildable_cell(sx -. 10.0, sy +. 10.0)
    && terrain_buildable_cell(sx +. 10.0, sy +. 10.0)
}

fn terrain_buildable_cell(x: Float, y: Float) -> Bool {
  let ax = float.absolute_value(x)
  let ay = float.absolute_value(y)
  case ax <=. 920.0 && ay <=. 920.0 {
    False -> False
    True -> {
      let normalized = {terrain_height(x, y) +. 1.0} /. 2.0
      normalized >=. 0.08 && normalized <. 0.84
    }
  }
}

fn snap_position(x: Float, y: Float) -> Position {
  let cell_x = float.truncate({x +. 1000.0} /. 20.0)
  let cell_y = float.truncate({y +. 1000.0} /. 20.0)
  let block_x = cell_x - cell_x % 2
  let block_y = cell_y - cell_y % 2
  Position(
    {int.to_float(block_x) +. 1.0} *. 20.0 -. 1000.0,
    {int.to_float(block_y) +. 1.0} *. 20.0 -. 1000.0,
  )
}

fn validate_coordinate(value: Float) -> Bool {
  value >. 0.0 -. world_limit
    && value <=. world_limit
}

fn too_close(world: World, x: Float, y: Float) -> Bool {
  list.any(all_positions(world), fn(position) { distance(position, Position(x, y)) <. minimum_distance })
}

fn all_positions(world: World) -> List(Position) {
  list.append(
    list.map(world.banks, fn(item) { item.position }),
    list.append(
      list.map(world.factories, fn(item) { item.position }),
      list.append(
        list.map(world.warehouses, fn(item) { item.position }),
        list.append(list.map(world.gatherers, fn(item) { item.position }), list.map(world.farms, fn(item) { item.position })),
      ),
    ),
  )
}

fn inside_owned_city(world: World, player_id: Int, x: Float, y: Float) -> Bool {
  list.any(world.banks, fn(bank) { bank.owner_id == player_id && distance(bank.position, Position(x, y)) <=. city_radius })
}

fn distance(a: Position, b: Position) -> Float {
  let dx = b.x -. a.x
  let dy = b.y -. a.y
  case float.square_root(dx *. dx +. dy *. dy) {
    Ok(value) -> value
    Error(Nil) -> 0.0
  }
}

fn find_player_by_uid(players: List(Player), uid: String) -> option.Option(Int) {
  case players {
    [] -> option.None
    [player, ..rest] -> case player.auth_uid == uid {
      True -> option.Some(player.id)
      False -> find_player_by_uid(rest, uid)
    }
  }
}

fn player_exists(world: World, player_id: Int) -> Bool { list.any(world.players, fn(player) { player.id == player_id }) }

fn is_online(world: World, player_id: Int) -> Bool { list.any(world.online_players, fn(id) { id == player_id }) }

fn session_valid(world: World, player_id: Int) -> Bool { player_exists(world, player_id) && is_online(world, player_id) }

fn player_authorized(world: World, player_id: Int) -> Bool { session_valid(world, player_id) && player_in_started_room(world, player_id) }

fn remove_online(ids: List(Int), player_id: Int) -> List(Int) {
  list.filter(ids, fn(id) { id != player_id })
}

fn nickname_taken(world: World, nickname: String, except_player_id: Int) -> Bool {
  list.any(world.players, fn(player) {
    player.id != except_player_id
      && is_online(world, player.id)
      && string.lowercase(player.name) == string.lowercase(nickname)
  })
}

fn valid_nickname(nickname: String) -> Bool {
  let trimmed = string.trim(nickname)
  let length = string.length(trimmed)
  length >= 3 && length <= 24
}

fn player_money(world: World, player_id: Int) -> Int {
  list.fold(world.players, 0, fn(money, player) {
    case player.id == player_id {
      True -> player.money
      False -> money
    }
  })
}

fn spend(world: World, player_id: Int, amount: Int) -> World {
  let players = list.map(world.players, fn(player) {
    case player.id == player_id {
      True -> Player(..player, money: player.money - amount)
      False -> player
    }
  })
  World(..world, players: players)
}

fn safe_name(name: String) -> String {
  case string.trim(name) {
    "" -> "Player"
    trimmed -> string.slice(trimmed, 0, 32)
  }
}

fn move_vehicle(vehicle: Vehicle) -> Vehicle {
  let Position(x, y) = vehicle.position
  let Position(tx, ty) = vehicle.target
  let dx = tx -. x
  let dy = ty -. y
  let d = distance(vehicle.position, vehicle.target)
  let step = vehicle.speed *. 0.05
  case d <=. step || d <=. 0.001 {
    True -> Vehicle(..vehicle, position: vehicle.target)
    False -> Vehicle(..vehicle, position: Position(x +. dx /. d *. step, y +. dy /. d *. step))
  }
}

fn get_player(players: List(Player), player_id: Int) -> Player {
  case players {
    [player, ..rest] -> case player.id == player_id { True -> player False -> get_player(rest, player_id) }
    [] -> Player(player_id, "", "", "", 0, 0, 0, 0, 0, 0)
  }
}

fn inventory_total(player: Player) -> Int { player.wood + player.stone + player.iron + player.gold + player.grain }

fn positive_or_zero(value: Int) -> Int {
  case value > 0 { True -> value False -> 0 }
}

fn add_product_capped(player: Player, product: messages.ProductType, amount: Int, capacity: Int) -> Player {
  let room = positive_or_zero(capacity - inventory_total(player))
  let amount = case amount < room { True -> amount False -> room }
  let updated = add_product(player, product, amount)
  Player(..updated, money: updated.money + messages.product_value(product) * amount)
}

fn add_product(player: Player, product: messages.ProductType, amount: Int) -> Player {
  case product {
    messages.Wood -> Player(..player, wood: player.wood + amount)
    messages.Stone -> Player(..player, stone: player.stone + amount)
    messages.Iron -> Player(..player, iron: player.iron + amount)
    messages.Gold -> Player(..player, gold: player.gold + amount)
    messages.Grain -> Player(..player, grain: player.grain + amount)
  }
}

fn player_storage_capacity(world: World, player_id: Int) -> Int {
  list.fold(world.warehouses, 0, fn(total, warehouse) {
    case warehouse.owner_id == player_id { True -> total + warehouse.capacity False -> total }
  })
}

fn inventory_json(player: Player) -> json.Json {
  json.object([
    #("wood", json.int(player.wood)),
    #("stone", json.int(player.stone)),
    #("iron", json.int(player.iron)),
    #("gold", json.int(player.gold)),
    #("grain", json.int(player.grain)),
  ])
}

fn player_in_started_room(world: World, player_id: Int) -> Bool {
  list.any(world.rooms, fn(room) { room.started && list.any(room.players, fn(id) { id == player_id }) })
}

fn player_room(world: World, player_id: Int) -> option.Option(Room) {
  list.fold(world.rooms, option.None, fn(found, room) {
    case found {
      option.Some(_) -> found
      option.None -> case list.any(room.players, fn(id) { id == player_id }) { True -> option.Some(room) False -> option.None }
    }
  })
}

fn room_by_id(world: World, code: String) -> option.Option(Room) {
  let normalized = string.uppercase(string.trim(code))
  list.fold(world.rooms, option.None, fn(found, room) {
    case found {
      option.Some(_) -> found
      option.None -> case string.uppercase(room.id) == normalized { True -> option.Some(room) False -> option.None }
    }
  })
}

fn create_room(world: World, player_id: Int, mode: String) -> #(World, Result(String, String)) {
  case session_valid(world, player_id) {
    False -> #(world, Error("Authentication required."))
    True -> case player_room(world, player_id) {
      option.Some(_) -> #(world, Error("You are already in a room."))
      option.None -> {
        let code = room_code(world.next_room_id)
        let mode = safe_mode(mode)
        let room = Room(code, player_id, mode, [player_id], False)
        let host = get_player(world.players, player_id)
        firestore.save_player(host.auth_token, host.auth_uid, host.name)
        firestore.save_room(host.auth_token, code, player_id, mode, [player_id], False)
        #(World(..world, rooms: [room, ..world.rooms], next_room_id: world.next_room_id + 1), Ok(code))
      }
    }
  }
}

fn join_room(world: World, player_id: Int, code: String) -> #(World, Result(String, String)) {
  case session_valid(world, player_id) {
    False -> #(world, Error("Authentication required."))
    True -> case player_room(world, player_id) {
      option.Some(existing) -> #(world, Error("You are already in room " <> existing.id <> "."))
      option.None -> case room_by_id(world, code) {
        option.None -> #(world, Error("Room not found."))
        option.Some(room) -> case room.started {
          True -> #(world, Error("Room has already started."))
          False -> case list.length(room.players) >= room_max_players {
            True -> #(world, Error("Room is full."))
            False -> {
              let updated = Room(..room, players: [player_id, ..room.players])
              let host = get_player(world.players, room.host_id)
              firestore.save_room(host.auth_token, room.id, room.host_id, room.mode, updated.players, updated.started)
              #(replace_room(world, updated), Ok(room.id))
            }
          }
        }
      }
    }
  }
}

fn start_room(world: World, player_id: Int) -> #(World, Result(Nil, String)) {
  case player_room(world, player_id) {
    option.None -> #(world, Error("You are not in a room."))
    option.Some(room) -> case room.host_id == player_id {
      False -> #(world, Error("Only the host can start the room."))
      True -> case list.length(room.players) < 2 {
        True -> #(world, Error("At least 2 players are required to start the room."))
        False -> {
          // Only reset state owned by this room. Other started rooms may be
          // running concurrently on the same authoritative world process.
          let prepared = reset_room_match_state(world, room.players)
          let updated = Room(..room, started: True)
          let host = get_player(prepared.players, room.host_id)
          firestore.save_room(host.auth_token, room.id, room.host_id, room.mode, updated.players, True)
          #(replace_room(prepared, updated), Ok(Nil))
        }
      }
    }
  }
}


fn leave_room(world: World, player_id: Int) -> #(World, Result(Nil, String)) {
  case player_room(world, player_id) {
    option.None -> #(world, Ok(Nil))
    option.Some(room) -> {
      let players = list.filter(room.players, fn(id) { id != player_id })
      let world = case players {
        [] -> reset_room_match_state(remove_room(world, room.id), room.players)
        _ -> {
          let cleaned = case room.started {
            True -> reset_player_match_state(world, player_id)
            False -> world
          }
          let new_host = case room.host_id == player_id { True -> hd(players) False -> room.host_id }
          let updated = Room(..room, host_id: new_host, players: players)
          let host = get_player(cleaned.players, new_host)
          firestore.save_room(host.auth_token, updated.id, updated.host_id, updated.mode, updated.players, updated.started)
          replace_room(cleaned, updated)
        }
      }
      #(world, Ok(Nil))
    }
  }
}

fn reset_player_match_state(world: World, player_id: Int) -> World {
  let players = list.map(world.players, fn(player) {
    case player.id == player_id {
      True -> Player(..player, money: starting_money, wood: 0, stone: 0, iron: 0, gold: 0, grain: 0)
      False -> player
    }
  })
  World(
    ..world,
    players: players,
    banks: list.filter(world.banks, fn(item) { item.owner_id != player_id }),
    factories: list.filter(world.factories, fn(item) { item.owner_id != player_id }),
    warehouses: list.filter(world.warehouses, fn(item) { item.owner_id != player_id }),
    gatherers: list.filter(world.gatherers, fn(item) { item.owner_id != player_id }),
    farms: list.filter(world.farms, fn(item) { item.owner_id != player_id }),
    vehicles: list.filter(world.vehicles, fn(item) { item.owner_id != player_id }),
  )
}

fn reset_room_match_state(world: World, player_ids: List(Int)) -> World {
  let players = list.map(world.players, fn(player) {
    case list.any(player_ids, fn(id) { id == player.id }) {
      True -> Player(..player, money: starting_money, wood: 0, stone: 0, iron: 0, gold: 0, grain: 0)
      False -> player
    }
  })
  let belongs_to_room = fn(owner_id: Int) {
    list.any(player_ids, fn(id) { id == owner_id })
  }
  World(
    ..world,
    players: players,
    banks: list.filter(world.banks, fn(item) { !belongs_to_room(item.owner_id) }),
    factories: list.filter(world.factories, fn(item) { !belongs_to_room(item.owner_id) }),
    warehouses: list.filter(world.warehouses, fn(item) { !belongs_to_room(item.owner_id) }),
    gatherers: list.filter(world.gatherers, fn(item) { !belongs_to_room(item.owner_id) }),
    farms: list.filter(world.farms, fn(item) { !belongs_to_room(item.owner_id) }),
    vehicles: list.filter(world.vehicles, fn(item) { !belongs_to_room(item.owner_id) }),
  )
}

fn hd(ids: List(Int)) -> Int { case ids { [first, ..] -> first [] -> 0 } }

fn remove_player_from_session(world: World, player_id: Int) -> World {
  let #(after_room, _) = leave_room(world, player_id)
  World(..after_room, online_players: remove_online(after_room.online_players, player_id))
}

fn replace_room(world: World, updated: Room) -> World {
  World(..world, rooms: list.map(world.rooms, fn(room) { case room.id == updated.id { True -> updated False -> room } }))
}

fn remove_room(world: World, room_id: String) -> World {
  World(..world, rooms: list.filter(world.rooms, fn(room) { room.id != room_id }))
}

fn room_code(value: Int) -> String {
  let text = int.to_string(value)
  case string.length(text) {
    1 -> "RM000" <> text
    2 -> "RM00" <> text
    3 -> "RM0" <> text
    _ -> "RM" <> text
  }
}

fn safe_mode(mode: String) -> String {
  case string.lowercase(string.trim(mode)) {
    "online" -> "online"
    _ -> "multiplayer"
  }
}

fn lobby_json(world: World, player_id: Int) -> Result(String, String) {
  let current = player_room(world, player_id)
  let room_payloads = world.rooms
    |> list.filter(fn(room) { !room.started })
    |> list.map(fn(room) {
      messages.RoomSummary(
        room.id,
        player_name(world, room.host_id),
        room.mode,
        list.map(room.players, fn(id) { player_name(world, id) }),
        room_max_players,
        room.started,
      )
    })
  let #(room_id, is_host, started, mode, host_name, players) = case current {
    option.None -> #(option.None, False, False, "online", "", [])
    option.Some(room) -> #(
      option.Some(room.id),
      room.host_id == player_id,
      room.started,
      room.mode,
      player_name(world, room.host_id),
      list.map(room.players, fn(id) { player_name(world, id) }),
    )
  }
  Ok(
    messages.encode_server(messages.LobbyState(
      room_id,
      is_host,
      started,
      mode,
      host_name,
      players,
      room_max_players,
      room_payloads,
    ))
  )
}

fn player_name(world: World, player_id: Int) -> String {
  list.fold(world.players, "Player", fn(current, player) { case player.id == player_id { True -> player.name False -> current } })
}

pub fn snapshot_json(world: World, player_id: Int) -> Result(String, String) {
  case session_valid(world, player_id) {
    False -> Error("Player session is not valid.")
    True -> {
      let player = get_player(world.players, player_id)
      let money = player_money(world, player_id)
      let inventory = inventory_json(player)
      let storage_capacity = player_storage_capacity(world, player_id)
      let room_players = case player_room(world, player_id) {
        option.Some(room) -> room.players
        option.None -> [player_id]
      }
      let visible_owner = fn(owner_id: Int) {
        list.any(room_players, fn(id) { id == owner_id })
      }
      let data = json.object([
        #("tick", json.int(world.tick)),
        #("money", json.int(money)),
        #("inventory", inventory),
        #("storage_used", json.int(inventory_total(player))),
        #("storage_capacity", json.int(storage_capacity)),
        #("in_game", json.bool(player_in_started_room(world, player_id))),
        #("banks", json.array(list.filter(world.banks, fn(item) { visible_owner(item.owner_id) }), bank_json)),
        #("factories", json.array(list.filter(world.factories, fn(item) { visible_owner(item.owner_id) }), factory_json)),
        #("warehouses", json.array(list.filter(world.warehouses, fn(item) { visible_owner(item.owner_id) }), warehouse_json)),
        #("gatherers", json.array(list.filter(world.gatherers, fn(item) { visible_owner(item.owner_id) }), simple_json)),
        #("farms", json.array(list.filter(world.farms, fn(item) { visible_owner(item.owner_id) }), simple_json)),
        #("vehicles", json.array(list.filter(world.vehicles, fn(item) { visible_owner(item.owner_id) }), vehicle_json)),
      ])
      let envelope = json.object([#("type", json.string("world_snapshot")), #("data", data)])
      Ok(envelope |> json.to_string)
    }
  }
}

fn bank_json(bank: Bank) -> json.Json {
  let Position(x, y) = bank.position
  json.object([#("id", json.int(bank.id)), #("owner_id", json.int(bank.owner_id)), #("x", json.float(x)), #("y", json.float(y))])
}
fn factory_json(factory: Factory) -> json.Json {
  let Position(x, y) = factory.position
  json.object([#("id", json.int(factory.id)), #("owner_id", json.int(factory.owner_id)), #("x", json.float(x)), #("y", json.float(y)), #("level", json.int(factory.level)), #("product", messages.product_json(factory.product))])
}
fn warehouse_json(warehouse: Warehouse) -> json.Json {
  let Position(x, y) = warehouse.position
  json.object([#("id", json.int(warehouse.id)), #("owner_id", json.int(warehouse.owner_id)), #("x", json.float(x)), #("y", json.float(y)), #("capacity", json.int(warehouse.capacity))])
}
fn simple_json(building: SimpleBuilding) -> json.Json {
  let Position(x, y) = building.position
  json.object([#("id", json.int(building.id)), #("owner_id", json.int(building.owner_id)), #("x", json.float(x)), #("y", json.float(y))])
}
fn vehicle_json(vehicle: Vehicle) -> json.Json {
  let Position(x, y) = vehicle.position
  let Position(tx, ty) = vehicle.target
  json.object([#("id", json.int(vehicle.id)), #("owner_id", json.int(vehicle.owner_id)), #("x", json.float(x)), #("y", json.float(y)), #("target_x", json.float(tx)), #("target_y", json.float(ty)), #("speed", json.float(vehicle.speed))])
}

pub fn handle_test_factory(world: World, x: Float, y: Float) -> World {
  let player = Player(1, "test-uid", "test", "", starting_money, 0, 0, 0, 0, 0)
  let room = Room("TEST", 1, "multiplayer", [1], True)
  let world = World(..world, players: [player], online_players: [1], rooms: [room])
  let #(world, _) = build_bank(world, 1, 0.0, 0.0)
  let #(world, _) = build_structure(world, 1, messages.Factory, x, y)
  world
}
