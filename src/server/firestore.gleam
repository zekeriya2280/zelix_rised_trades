import gleam/erlang/process
import gleam/http
import gleam/http/request
import gleam/httpc
import gleam/int
import gleam/io
import gleam/json
import gleam/list
import gleam/string
import server/firebase_config

const firestore_endpoint = "https://firestore.googleapis.com/v1"

/// Persist a player account (keyed by its Firebase `localId`) to the
/// Firestore `players` collection. The write is authorized as the end user
/// with their Firebase ID token, so it is subject to Firestore security rules.
/// It runs on a background process so the request/world loop is never blocked.
pub fn save_player(auth_token: String, uid: String, nickname: String) -> Nil {
  spawn_write(auth_token, "players", uid, player_fields(uid, nickname))
}

/// Persist a newly created room to the Firestore `rooms` collection.
pub fn save_room(
  auth_token: String,
  code: String,
  host_id: Int,
  mode: String,
  player_ids: List(Int),
) -> Nil {
  spawn_write(auth_token, "rooms", code, room_fields(code, host_id, mode, player_ids))
}

/// Firestore document field values are typed objects, e.g.
/// `{"stringValue": "..."}`. These builders wrap plain values into that shape.
fn firestore_string(value: String) -> json.Json {
  json.object([#("stringValue", json.string(value))])
}

fn firestore_int(value: Int) -> json.Json {
  json.object([#("integerValue", json.string(int.to_string(value)))])
}

fn firestore_bool(value: Bool) -> json.Json {
  json.object([#("booleanValue", json.bool(value))])
}

fn firestore_array(values: List(json.Json)) -> json.Json {
  let entries = json.array(values, fn(value) { value })
  json.object([#("arrayValue", json.object([#("values", entries)]))])
}

fn player_fields(uid: String, nickname: String) -> json.Json {
  json.object([
    #("uid", firestore_string(uid)),
    #("nickname", firestore_string(nickname)),
  ])
}

fn room_fields(
  code: String,
  host_id: Int,
  mode: String,
  player_ids: List(Int),
) -> json.Json {
  json.object([
    #("code", firestore_string(code)),
    #("host_id", firestore_int(host_id)),
    #("mode", firestore_string(mode)),
    #("started", firestore_bool(False)),
    #("players", firestore_array(list.map(player_ids, firestore_int))),
  ])
}

/// Fire-and-forget: spawn a process that performs the synchronous REST call
/// and then exits, leaving the caller (world loop / auth handler) responsive.
fn spawn_write(
  auth_token: String,
  collection: String,
  doc_id: String,
  fields: json.Json,
) -> Nil {
  let _ =
    process.spawn(fn() {
      case perform_write(auth_token, collection, doc_id, fields) {
        Ok(Nil) ->
          io.println("[firestore] wrote " <> collection <> "/" <> doc_id)
        Error(message) ->
          io.println("[firestore] write FAILED for " <> collection <> "/" <> doc_id <> ": " <> message)
      }
    })
  Nil
}

fn perform_write(
  auth_token: String,
  collection: String,
  doc_id: String,
  fields: json.Json,
) -> Result(Nil, String) {
  case firebase_config.firebase_config() {
    Error(message) -> Error(message)
    Ok(config) -> {
      let url =
        firestore_endpoint
          <> "/projects/"
          <> config.project_id
          <> "/databases/%28default%29/documents/"
          <> collection
          <> "/"
          <> doc_id
      let body = json.object([#("fields", fields)]) |> json.to_string
      case request.to(url) {
        Error(_) ->
          Error(
            "Could not parse Firestore URL (collection: " <> collection <> ").",
          )
        Ok(req0) -> {
          let req =
            req0
            |> request.set_method(http.Patch)
            |> request.prepend_header("content-type", "application/json")
            |> request.prepend_header("authorization", "Bearer " <> auth_token)
            |> request.set_body(body)
          case httpc.send(req) {
            Ok(response) -> case response.status {
              200 | 201 -> Ok(Nil)
              code ->
                Error(
                  "Firestore write failed with status: "
                    <> int.to_string(code)
                    <> " body: "
                    <> response.body,
                )
            }
            Error(error) ->
              Error("Firestore request failed: " <> string.inspect(error))
          }
        }
      }
    }
  }
}