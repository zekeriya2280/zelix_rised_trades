import gleam/dynamic/decode
import gleam/json

pub type BuildingType { Gatherer Factory Warehouse Farm }
pub type ProductType { Wood Stone Iron Gold Grain }

pub type ClientMessage {
  Join(name: String, token: String)
  Ping
  RequestSnapshot
  BuildBank(x: Float, y: Float)
  BuildStructure(building: BuildingType, x: Float, y: Float)
  SpawnVehicle(x: Float, y: Float, target_x: Float, target_y: Float, speed: Float)
  SetFactoryProduct(id: Int, product: ProductType)
}

pub type ServerMessage {
  Welcome(player_id: Int)
  Pong
  WorldSnapshot(data: String)
  ServerError(message: String)
  CommandRejected(message: String)
}

pub fn building_cost(building: BuildingType) -> Int {
  case building { Gatherer -> 5000 Factory -> 20000 Warehouse -> 8000 Farm -> 12000 }
}

pub fn product_value(product: ProductType) -> Int {
  case product { Wood -> 80 Stone -> 90 Iron -> 140 Gold -> 220 Grain -> 70 }
}

pub fn product_json(product: ProductType) -> json.Json {
  case product { Wood -> json.string("wood") Stone -> json.string("stone") Iron -> json.string("iron") Gold -> json.string("gold") Grain -> json.string("grain") }
}

pub fn encode_server(message: ServerMessage) -> String {
  case message {
    Welcome(player_id:) -> json.object([#("type", json.string("welcome")), #("player_id", json.int(player_id))]) |> json.to_string
    Pong -> json.object([#("type", json.string("pong"))]) |> json.to_string
    WorldSnapshot(data:) -> data
    ServerError(message:) -> json.object([#("type", json.string("error")), #("message", json.string(message))]) |> json.to_string
    CommandRejected(message:) -> json.object([#("type", json.string("command_rejected")), #("message", json.string(message))]) |> json.to_string
  }
}

pub fn decode_client(text: String) -> Result(ClientMessage, String) {
  let decoder = {
    use tag <- decode.field("type", decode.string)
    case tag {
      "join" -> {
        use name <- decode.field("name", decode.string)
        use token <- decode.field("token", decode.string)
        decode.success(Join(name, token))
      }
      "ping" -> decode.success(Ping)
      "request_snapshot" -> decode.success(RequestSnapshot)
      "build_bank" -> {
        use x <- decode.field("x", decode.float)
        use y <- decode.field("y", decode.float)
        decode.success(BuildBank(x, y))
      }
      "build_structure" -> {
        use building <- decode.field("building_type", decode_building())
        use x <- decode.field("x", decode.float)
        use y <- decode.field("y", decode.float)
        decode.success(BuildStructure(building, x, y))
      }
      "spawn_vehicle" -> {
        use x <- decode.field("x", decode.float)
        use y <- decode.field("y", decode.float)
        use tx <- decode.field("target_x", decode.float)
        use ty <- decode.field("target_y", decode.float)
        use speed <- decode.field("speed", decode.float)
        decode.success(SpawnVehicle(x, y, tx, ty, speed))
      }
      "set_factory_product" -> {
        use id <- decode.field("id", decode.int)
        use product <- decode.field("product", decode_product())
        decode.success(SetFactoryProduct(id, product))
      }
      _ -> decode.failure(Ping, expected: "known client message")
    }
  }
  case json.parse(text, using: decoder) { Ok(message) -> Ok(message) Error(_) -> Error("Invalid client message") }
}

fn decode_building() -> decode.Decoder(BuildingType) {
  decode.then(decode.string, fn(text) {
    case text {
      "gatherer" -> decode.success(Gatherer)
      "factory" -> decode.success(Factory)
      "warehouse" -> decode.success(Warehouse)
      "farm" -> decode.success(Farm)
      _ -> decode.failure(Gatherer, expected: "building_type")
    }
  })
}

fn decode_product() -> decode.Decoder(ProductType) {
  decode.then(decode.string, fn(text) {
    case text {
      "wood" -> decode.success(Wood)
      "stone" -> decode.success(Stone)
      "iron" -> decode.success(Iron)
      "gold" -> decode.success(Gold)
      "grain" -> decode.success(Grain)
      _ -> decode.failure(Wood, expected: "product")
    }
  })
}
