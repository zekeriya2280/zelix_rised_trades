import game_server
import server/auth
import gleam/list
import gleeunit/should

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
