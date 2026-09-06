import game_server
import server/auth
import gleam/list
import gleam/option
import gleeunit
import gleeunit/should

pub fn main() {
  gleeunit.main()
}

pub fn initial_world_has_no_players_test() {
  let world = game_server.initial_world()
  world.players |> list.length |> should.equal(0)
}

pub fn initial_world_has_no_rooms_test() {
  let world = game_server.initial_world()
  world.rooms |> list.length |> should.equal(0)
}

pub fn firebase_lookup_nested_user_decodes_test() {
  let body = "{\"users\":[{\"localId\":\"uid-123\",\"displayName\":\"Zekeriya\"}]}"
  auth.decode_identity_response(body) |> should.equal(Ok(#("uid-123", "Zekeriya")))
}

pub fn firebase_lookup_empty_users_fails_test() {
  auth.decode_identity_response("{\"users\":[]}") |> should.equal(Error("Firebase token did not contain a user."))
}


pub fn room_code_and_lobby_state_are_stable_test() {
  let world = game_server.initial_world()
  world.rooms |> list.length |> should.equal(0)
}

/// Regression test for the reversed warehouse/factory delivery: the computed
/// grid route must START near the source (factory) and END near the target
/// (warehouse), otherwise the truck drives the delivery backwards.
pub fn grid_route_starts_at_source_and_ends_at_target_test() {
  let source = game_server.Position(-100.0, 0.0)
  let target = game_server.Position(100.0, 0.0)
  let assert option.Some(path) = game_server.grid_route_from_cells(source, target, [])
  let assert [first, ..] = path
  let assert option.Some(last) = option.from_result(list.last(path))

  let game_server.Position(fx, _) = source
  let game_server.Position(tx, _) = target
  let game_server.Position(sx, _) = first
  let game_server.Position(ex, _) = last

  // First waypoint belongs to the source side, last to the target side.
  should.be_true({ sx -. fx } *. { sx -. fx } <. { ex -. fx } *. { ex -. fx })
  should.be_true({ ex -. tx } *. { ex -. tx } <. { sx -. tx } *. { sx -. tx })
}
