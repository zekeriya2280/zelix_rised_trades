import gleam/erlang/process
import game_server
import server/websocket

pub fn main() -> Nil {
  let world = game_server.start()
  let _ = websocket.start(world)
  process.sleep_forever()
}
