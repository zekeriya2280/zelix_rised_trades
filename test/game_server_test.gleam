import game_server
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
