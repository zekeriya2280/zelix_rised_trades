import gleam/erlang/process
import gleam/http
import gleam/http/request
import gleam/http/response
import gleam/bytes_tree
import gleam/json
import gleam/option
import mist
import game_server
import server/auth
import server/messages

@external(erlang, "game_server_os_ffi", "get_env")
fn get_env(name: String) -> Result(String, Nil)

/// CORS origin for the auth endpoints. Defaults to "*" for local/dev use
/// (matching the project's previous behavior), but production deployments
/// should set the ALLOWED_ORIGIN environment variable to their real Web
/// origin (e.g. "https://play.example.com") to avoid allowing arbitrary
/// third-party sites to call the authenticated endpoints from a browser.
fn allowed_origin() -> String {
  case get_env("ALLOWED_ORIGIN") {
    Ok(value) -> value
    Error(_) -> "*"
  }
}

type WsState {
  WsState(world: process.Subject(game_server.Message), player_id: option.Option(Int))
}

pub fn handle(
  request: request.Request(mist.Connection),
  world: process.Subject(game_server.Message),
) -> response.Response(mist.ResponseData) {
  case request.path {
    "/ws" ->
      mist.websocket(
        request: request,
        handler: handle_ws,
        on_init: fn(_connection) {
          #(WsState(world, option.None), option.None)
        },
        on_close: fn(state) { disconnect_player(state) },
      )

    "/health" ->
      cors(text(200, "ok"))

    "/auth/login" ->
      auth_response(request, "login")

    "/auth/register" ->
      auth_response(request, "register")

    _ ->
      text(404, "not found")
  }
}

fn handle_ws(
  state: WsState,
  message: mist.WebsocketMessage(Nil),
  connection: mist.WebsocketConnection,
) -> mist.Next(WsState, Nil) {
  case message {
    mist.Text(text) -> {
      case messages.decode_client(text) {
        Ok(messages.Join(token)) ->
          handle_join(state, connection, token)

        Ok(messages.Ping) ->
          handle_ping(state, connection)

        Ok(messages.RequestSnapshot) ->
          handle_snapshot(state, connection)

        Ok(messages.LobbyCreate(mode)) ->
          handle_lobby_create(state, connection, mode)

        Ok(messages.LobbyJoin(code)) ->
          handle_lobby_join(state, connection, code)

        Ok(messages.LobbyStart) ->
          handle_lobby_start(state, connection)

        Ok(messages.LobbyLeave) ->
          handle_lobby_leave(state, connection)

        Ok(messages.BuildBank(x, y)) ->
          handle_build_bank(state, connection, x, y)

        Ok(messages.BuildStructure(building, x, y)) ->
          handle_build_structure(state, connection, building, x, y)

        Ok(messages.SpawnVehicle(x, y, tx, ty, speed)) ->
          handle_spawn_vehicle(state, connection, x, y, tx, ty, speed)

        Ok(messages.SetFactoryProduct(id, product)) ->
          handle_set_factory_product(state, connection, id, product)

        Error(message) ->
          send_and_continue(
            state,
            connection,
            messages.ServerError(message),
          )
      }
    }

    mist.Closed | mist.Shutdown ->
      mist.stop()

    _ ->
      mist.continue(state)
  }
}

fn handle_join(
  state: WsState,
  connection: mist.WebsocketConnection,
  token: String,
) -> mist.Next(WsState, Nil) {
  case state.player_id {
    option.Some(_) ->
      send_and_stop(
        state,
        connection,
        messages.ServerError("Already authenticated."),
      )

    option.None ->
      case token == "" {
        True ->
          send_and_stop(
            state,
            connection,
            messages.ServerError("Authentication required."),
          )

        False ->
          case auth.verify_identity(token) {
            Error(_) ->
              send_and_stop(
                state,
                connection,
                messages.ServerError("Invalid authentication token."),
              )

            Ok(#(uid, nickname)) -> {
              let reply = process.new_subject()

              process.send(
                state.world,
                game_server.JoinPlayer(uid, nickname, token, reply),
              )

              case process.receive(reply, within: 1000) {
                Ok(Ok(player_id)) -> {
                  let new_state =
                    WsState(state.world, option.Some(player_id))

                  let _ =
                    ignore_send(
                      connection,
                      messages.Welcome(player_id),
                    )

                  let _ =
                    send_lobby_for(
                      new_state,
                      connection,
                    )

                  case send_snapshot_for(new_state, connection) {
                    Ok(_) ->
                      mist.continue(new_state)

                    Error(message) ->
                      send_and_stop(
                        new_state,
                        connection,
                        messages.ServerError(message),
                      )
                  }
                }

                Ok(Error(message)) ->
                  send_and_stop(
                    state,
                    connection,
                    messages.ServerError(message),
                  )

                Error(Nil) ->
                  send_and_stop(
                    state,
                    connection,
                    messages.ServerError("World timeout."),
                  )
              }
            }
          }
      }
  }
}

fn handle_ping(
  state: WsState,
  connection: mist.WebsocketConnection,
) -> mist.Next(WsState, Nil) {
  let _ =
    ignore_send(
      connection,
      messages.Pong,
    )

  let _ =
    send_lobby_for(
      state,
      connection,
    )

  mist.continue(state)
}

fn handle_lobby_create(
  state: WsState,
  connection: mist.WebsocketConnection,
  mode: String,
) -> mist.Next(WsState, Nil) {
  case state.player_id {
    option.None ->
      send_and_continue(
        state,
        connection,
        messages.ServerError("Authentication required."),
      )

    option.Some(player_id) -> {
      let reply = process.new_subject()

      process.send(
        state.world,
        game_server.CreateRoom(player_id, mode, reply),
      )

      case process.receive(reply, within: 1000) {
        Ok(Ok(_)) -> {
          let _ =
            send_lobby_for(
              state,
              connection,
            )

          mist.continue(state)
        }

        Ok(Error(message)) ->
          send_and_continue(
            state,
            connection,
            messages.CommandRejected(message),
          )

        Error(Nil) ->
          send_and_continue(
            state,
            connection,
            messages.ServerError("Lobby timeout."),
          )
      }
    }
  }
}

fn handle_lobby_join(
  state: WsState,
  connection: mist.WebsocketConnection,
  code: String,
) -> mist.Next(WsState, Nil) {
  case state.player_id {
    option.None ->
      send_and_continue(
        state,
        connection,
        messages.ServerError("Authentication required."),
      )

    option.Some(player_id) -> {
      let reply = process.new_subject()

      process.send(
        state.world,
        game_server.JoinRoom(player_id, code, reply),
      )

      case process.receive(reply, within: 1000) {
        Ok(Ok(_)) -> {
          let _ =
            send_lobby_for(
              state,
              connection,
            )

          mist.continue(state)
        }

        Ok(Error(message)) ->
          send_and_continue(
            state,
            connection,
            messages.CommandRejected(message),
          )

        Error(Nil) ->
          send_and_continue(
            state,
            connection,
            messages.ServerError("Lobby timeout."),
          )
      }
    }
  }
}

fn handle_lobby_start(
  state: WsState,
  connection: mist.WebsocketConnection,
) -> mist.Next(WsState, Nil) {
  case state.player_id {
    option.None ->
      send_and_continue(
        state,
        connection,
        messages.ServerError("Authentication required."),
      )

    option.Some(player_id) -> {
      let reply = process.new_subject()

      process.send(
        state.world,
        game_server.StartRoom(player_id, reply),
      )

      case process.receive(reply, within: 1000) {
        Ok(Ok(Nil)) -> {
          let _ =
            send_lobby_for(
              state,
              connection,
            )

          let _ =
            send_snapshot_for(
              state,
              connection,
            )

          mist.continue(state)
        }

        Ok(Error(message)) ->
          send_and_continue(
            state,
            connection,
            messages.CommandRejected(message),
          )

        Error(Nil) ->
          send_and_continue(
            state,
            connection,
            messages.ServerError("Lobby timeout."),
          )
      }
    }
  }
}

fn handle_lobby_leave(
  state: WsState,
  connection: mist.WebsocketConnection,
) -> mist.Next(WsState, Nil) {
  case state.player_id {
    option.None ->
      send_and_continue(
        state,
        connection,
        messages.ServerError("Authentication required."),
      )

    option.Some(player_id) -> {
      let reply = process.new_subject()

      process.send(
        state.world,
        game_server.LeaveRoom(player_id, reply),
      )

      case process.receive(reply, within: 1000) {
        Ok(Ok(Nil)) -> {
          let _ =
            send_lobby_for(
              state,
              connection,
            )

          let _ =
            send_snapshot_for(
              state,
              connection,
            )

          mist.continue(state)
        }

        Ok(Error(message)) ->
          send_and_continue(
            state,
            connection,
            messages.CommandRejected(message),
          )

        Error(Nil) ->
          send_and_continue(
            state,
            connection,
            messages.ServerError("Lobby timeout."),
          )
      }
    }
  }
}

fn handle_snapshot(
  state: WsState,
  connection: mist.WebsocketConnection,
) -> mist.Next(WsState, Nil) {
  case state.player_id {
    option.None ->
      send_and_continue(
        state,
        connection,
        messages.ServerError("Authentication required."),
      )

    option.Some(_) ->
      case send_snapshot_for(state, connection) {
        Ok(_) ->
          mist.continue(state)

        Error(message) ->
          send_and_continue(
            state,
            connection,
            messages.ServerError(message),
          )
      }
  }
}

fn handle_build_bank(
  state: WsState,
  connection: mist.WebsocketConnection,
  x: Float,
  y: Float,
) -> mist.Next(WsState, Nil) {
  case state.player_id {
    option.None ->
      send_and_continue(
        state,
        connection,
        messages.ServerError("Authentication required."),
      )

    option.Some(player_id) -> {
      let reply = process.new_subject()

      process.send(
        state.world,
        game_server.BuildBank(player_id, x, y, reply),
      )

      send_command_result(
        state,
        connection,
        reply,
      )
    }
  }
}

fn handle_build_structure(
  state: WsState,
  connection: mist.WebsocketConnection,
  building: messages.BuildingType,
  x: Float,
  y: Float,
) -> mist.Next(WsState, Nil) {
  case state.player_id {
    option.None ->
      send_and_continue(
        state,
        connection,
        messages.ServerError("Authentication required."),
      )

    option.Some(player_id) -> {
      let reply = process.new_subject()

      process.send(
        state.world,
        game_server.BuildStructure(
          player_id,
          building,
          x,
          y,
          reply,
        ),
      )

      send_command_result(
        state,
        connection,
        reply,
      )
    }
  }
}

fn handle_spawn_vehicle(
  state: WsState,
  connection: mist.WebsocketConnection,
  x: Float,
  y: Float,
  tx: Float,
  ty: Float,
  speed: Float,
) -> mist.Next(WsState, Nil) {
  case state.player_id {
    option.None ->
      send_and_continue(
        state,
        connection,
        messages.ServerError("Authentication required."),
      )

    option.Some(player_id) -> {
      let reply = process.new_subject()

      process.send(
        state.world,
        game_server.SpawnVehicle(
          player_id,
          x,
          y,
          tx,
          ty,
          speed,
          reply,
        ),
      )

      send_command_result(
        state,
        connection,
        reply,
      )
    }
  }
}

fn handle_set_factory_product(
  state: WsState,
  connection: mist.WebsocketConnection,
  id: Int,
  product: messages.ProductType,
) -> mist.Next(WsState, Nil) {
  case state.player_id {
    option.None ->
      send_and_continue(
        state,
        connection,
        messages.ServerError("Authentication required."),
      )

    option.Some(player_id) -> {
      let reply = process.new_subject()

      process.send(
        state.world,
        game_server.SetFactoryProduct(
          player_id,
          id,
          product,
          reply,
        ),
      )

      send_command_result(
        state,
        connection,
        reply,
      )
    }
  }
}

fn send_command_result(
  state: WsState,
  connection: mist.WebsocketConnection,
  reply: process.Subject(Result(Nil, String)),
) -> mist.Next(WsState, Nil) {
  case process.receive(reply, within: 1000) {
    Ok(Ok(Nil)) ->
      handle_snapshot(
        state,
        connection,
      )

    Ok(Error(message)) ->
      send_and_continue(
        state,
        connection,
        messages.CommandRejected(message),
      )

    Error(Nil) ->
      send_and_continue(
        state,
        connection,
        messages.ServerError("World timeout."),
      )
  }
}

fn send_lobby_for(
  state: WsState,
  connection: mist.WebsocketConnection,
) -> Result(Nil, String) {
  case state.player_id {
    option.None ->
      Error("Authentication required.")

    option.Some(player_id) -> {
      let reply = process.new_subject()

      process.send(
        state.world,
        game_server.GetLobby(player_id, reply),
      )

      case process.receive(reply, within: 1000) {
        Ok(Ok(data)) ->
          case mist.send_text_frame(connection, data) {
            Ok(Nil) ->
              Ok(Nil)

            Error(_) ->
              Error("Failed to send lobby state.")
          }

        Ok(Error(message)) ->
          Error(message)

        Error(Nil) ->
          Error("Lobby timeout.")
      }
    }
  }
}

fn send_snapshot_for(
  state: WsState,
  connection: mist.WebsocketConnection,
) -> Result(Nil, String) {
  case state.player_id {
    option.None ->
      Error("Authentication required.")

    option.Some(player_id) -> {
      let reply = process.new_subject()

      process.send(
        state.world,
        game_server.GetSnapshot(player_id, reply),
      )

      case process.receive(reply, within: 1000) {
        Ok(Ok(snapshot)) -> {
          case mist.send_text_frame(connection, snapshot) {
            Ok(Nil) ->
              Ok(Nil)

            Error(_) ->
              Error("Failed to send snapshot.")
          }
        }

        Ok(Error(message)) ->
          Error(message)

        Error(Nil) ->
          Error("World timeout.")
      }
    }
  }
}

fn send_and_stop(
  _state: WsState,
  connection: mist.WebsocketConnection,
  message: messages.ServerMessage,
) -> mist.Next(WsState, Nil) {
  let _ =
    ignore_send(
      connection,
      message,
    )

  mist.stop()
}

fn send_and_continue(
  state: WsState,
  connection: mist.WebsocketConnection,
  message: messages.ServerMessage,
) -> mist.Next(WsState, Nil) {
  let _ =
    ignore_send(
      connection,
      message,
    )

  mist.continue(state)
}

fn ignore_send(
  connection: mist.WebsocketConnection,
  message: messages.ServerMessage,
) {
  let _ =
    mist.send_text_frame(
      connection,
      messages.encode_server(message),
    )
}

fn disconnect_player(state: WsState) {
  case state.player_id {
    option.Some(player_id) ->
      process.send(
        state.world,
        game_server.LeavePlayer(player_id),
      )

    option.None ->
      Nil
  }
}

fn text(
  status: Int,
  body: String,
) -> response.Response(mist.ResponseData) {
  response.new(status)
  |> response.set_header(
    "content-type",
    "text/plain; charset=utf-8",
  )
  |> response.set_body(
    mist.Bytes(
      bytes_tree.from_string(body),
    ),
  )
}

fn cors(
  resp: response.Response(mist.ResponseData),
) -> response.Response(mist.ResponseData) {
  resp
  |> response.set_header(
    "access-control-allow-origin",
    allowed_origin(),
  )
  |> response.set_header(
    "access-control-allow-methods",
    "POST, OPTIONS",
  )
  |> response.set_header(
    "access-control-allow-headers",
    "content-type, authorization",
  )
}

fn auth_response(
  request: request.Request(mist.Connection),
  action: String,
) -> response.Response(mist.ResponseData) {
  case request.method {
    http.Options ->
      cors(
        text(
          204,
          "",
        ),
      )

    http.Post ->
      case mist.read_body(request, 64 * 1024) {
        Ok(body_request) -> {
          let result =
            auth.handle(
              action,
              body_request.body,
            )

          let body =
            json.object([
              #("ok", json.bool(result.ok)),
              #("message", json.string(result.message)),
              #("nickname", json.string(result.nickname)),
              #("token", json.string(result.token)),
            ])
            |> json.to_string

          let status =
            case result.ok {
              True -> 200
              False -> 401
            }

          response.new(status)
          |> response.set_header(
            "content-type",
            "application/json",
          )
          |> response.set_body(
            mist.Bytes(
              bytes_tree.from_string(body),
            ),
          )
          |> cors
        }

        Error(_) ->
          cors(
            text(
              400,
              "invalid request body",
            ),
          )
      }

    _ ->
      cors(
        text(
          405,
          "method not allowed",
        ),
      )
  }
}