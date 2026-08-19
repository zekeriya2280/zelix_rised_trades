import gleam/float
import gleam/json
import gleam/int
import gleam/list
import gleam/option
import gleam/string
import gleam/erlang/process
import server/messages

pub type Position { Position(x: Float, y: Float) }

pub type Player { Player(id: Int, auth_uid: String, name: String, money: Int) }
pub type Bank { Bank(id: Int, owner_id: Int, position: Position) }
pub type Factory { Factory(id: Int, owner_id: Int, position: Position, level: Int, product: messages.ProductType) }
pub type Warehouse { Warehouse(id: Int, owner_id: Int, position: Position, capacity: Int) }
pub type SimpleBuilding { SimpleBuilding(id: Int, owner_id: Int, position: Position) }
pub type Vehicle { Vehicle(id: Int, owner_id: Int, position: Position, target: Position, speed: Float) }

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
  )
}

pub type Message {
  JoinPlayer(auth_uid: String, name: String, reply_to: process.Subject(Result(Int, String)))
  LeavePlayer(player_id: Int)
  BuildBank(player_id: Int, x: Float, y: Float, reply_to: process.Subject(Result(Nil, String)))
  BuildStructure(player_id: Int, building: messages.BuildingType, x: Float, y: Float, reply_to: process.Subject(Result(Nil, String)))
  SpawnVehicle(player_id: Int, x: Float, y: Float, target_x: Float, target_y: Float, speed: Float, reply_to: process.Subject(Result(Nil, String)))
  SetFactoryProduct(player_id: Int, factory_id: Int, product: messages.ProductType, reply_to: process.Subject(Result(Nil, String)))
  GetSnapshot(player_id: Int, reply_to: process.Subject(Result(String, String)))
}

const starting_money = 100000
const bank_cost = 10000
const city_radius = 300.0
const minimum_distance = 50.0
const vehicle_speed_max = 500.0
const world_limit = 1000.0

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
  World(0, 1, 1, [], [], [], [], [], [], [], [])
}

fn loop(subject: process.Subject(Message), world: World) -> Nil {
  case process.receive(subject, within: 1000) {
    Ok(message) -> loop(subject, handle(message, world))
    Error(Nil) -> loop(subject, update(world))
  }
}

fn handle(message: Message, world: World) -> World {
  case message {
    JoinPlayer(auth_uid, name, reply_to) -> {
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
                  World(..world, online_players: [id, ..world.online_players])
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
                let player = Player(world.next_player_id, auth_uid, nickname, starting_money)
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
    LeavePlayer(player_id) -> {
      World(..world, online_players: remove_online(world.online_players, player_id))
    }
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
    case next_tick % 5 == 0 {
      True -> list.map(world.players, fn(player) { produce_for_player(player, world.factories) })
      False -> world.players
    }
  World(..world, tick: next_tick, players: players, vehicles: vehicles)
}

fn produce_for_player(player: Player, factories: List(Factory)) -> Player {
  let count = list.fold(factories, 0, fn(total, factory) {
    case factory.owner_id == player.id {
      True -> total + messages.product_value(factory.product) * factory.level
      False -> total
    }
  })
  Player(..player, money: player.money + count)
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
  value >=. 0.0 -. world_limit && value <=. world_limit
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

fn player_authorized(world: World, player_id: Int) -> Bool { player_exists(world, player_id) && is_online(world, player_id) }

fn remove_online(ids: List(Int), player_id: Int) -> List(Int) {
  list.filter(ids, fn(id) { id != player_id })
}

fn nickname_taken(world: World, nickname: String, except_player_id: Int) -> Bool {
  list.any(world.players, fn(player) {
    player.id != except_player_id && is_online(world, player.id) && string.lowercase(player.name) == string.lowercase(nickname)
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
  case d <=. vehicle.speed || d <=. 0.001 {
    True -> Vehicle(..vehicle, position: vehicle.target)
    False -> Vehicle(..vehicle, position: Position(x +. dx /. d *. vehicle.speed, y +. dy /. d *. vehicle.speed))
  }
}

pub fn snapshot_json(world: World, player_id: Int) -> Result(String, String) {
  case player_authorized(world, player_id) {
    False -> Error("Player session is not valid.")
    True -> {
      let money = player_money(world, player_id)
      let data = json.object([
        #("tick", json.int(world.tick)),
        #("money", json.int(money)),
        #("banks", json.array(world.banks, bank_json)),
        #("factories", json.array(world.factories, factory_json)),
        #("warehouses", json.array(world.warehouses, warehouse_json)),
        #("gatherers", json.array(world.gatherers, simple_json)),
        #("farms", json.array(world.farms, simple_json)),
        #("vehicles", json.array(world.vehicles, vehicle_json)),
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
  let player = Player(1, "test-uid", "test", starting_money)
  let world = World(..world, players: [player], online_players: [1])
  let #(world, _) = build_bank(world, 1, 0.0, 0.0)
  let #(world, _) = build_structure(world, 1, messages.Factory, x, y)
  world
}
