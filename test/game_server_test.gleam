import game_server
import server/auth
import gleam/list
import gleeunit/should
import gleam/string

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


pub fn snapshots_are_scoped_to_the_players_room_test() {
  let player_one =
    game_server.Player(1, "uid-1", "One", "", 100000, 0, 0, 0, 0, 0)

  let player_two =
    game_server.Player(2, "uid-2", "Two", "", 100000, 0, 0, 0, 0, 0)

  let room_one =
    game_server.Room("RM0001", 1, "multiplayer", [1], True)

  let room_two =
    game_server.Room("RM0002", 2, "multiplayer", [2], True)

  let bank_one =
    game_server.Bank(
      1,
      1,
      game_server.Position(0.0, 0.0),
    )

  let bank_two =
    game_server.Bank(
      2,
      2,
      game_server.Position(100.0, 100.0),
    )

  let world =
    game_server.World(
      0,
      3,
      3,
      [player_one, player_two],
      [bank_one, bank_two],
      [],
      [],
      [],
      [],
      [],
      [1, 2],
      [room_one, room_two],
      3,
    )

  let snapshot =
    game_server.snapshot_json(world, 1)
    |> should.be_ok

  snapshot |> string.contains("\"id\":1") |> should.equal(True)
  snapshot |> string.contains("\"id\":2") |> should.equal(False)
}
