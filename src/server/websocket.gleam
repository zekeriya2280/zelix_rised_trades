import gleam/erlang/process
import mist
import game_server
import server/router

pub fn start(world: process.Subject(game_server.Message)) {
  let builder =
    mist.new(fn(request) { router.handle(request, world) })
    |> mist.bind("0.0.0.0")
    |> mist.port(8765)
  mist.start(builder)
}
