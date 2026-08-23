import gleam/bit_array
import gleam/dynamic/decode
import gleam/http
import gleam/http/request
import gleam/httpc
import gleam/int
import gleam/json
import gleam/option
import gleam/string
import server/firebase_config
import server/firestore

const identity_endpoint = "https://identitytoolkit.googleapis.com/v1"

pub type AuthResult {
  AuthResult(ok: Bool, message: String, nickname: String, token: String)
}

pub fn verify_identity(token: String) -> Result(#(String, String), String) {
  case firebase_config.firebase_config() {
    Error(message) -> Error(message)
    Ok(config) -> {
      let body = json.object([#("idToken", json.string(token))]) |> json.to_string
      case firebase_post(config.api_key, "/accounts:lookup", body) {
        Ok(text) -> decode_identity_response(text)
        Error(message) -> Error(message)
      }
    }
  }
}

pub fn decode_identity_response(text: String) -> Result(#(String, String), String) {
  let decoder = {
    use users <- decode.field("users", decode.list(firebase_user_decoder()))
    decode.success(users)
  }
  case json.parse(text, using: decoder) {
    Ok([user, .._]) -> {
      let nickname = user.display_name |> option.unwrap("") |> string.trim
      case string.length(nickname) >= 3 && string.length(nickname) <= 24 {
        True -> Ok(#(user.local_id, nickname))
        False -> Error("Firebase account does not have a valid nickname.")
      }
    }
    Ok([]) -> Error("Firebase token did not contain a user.")
    Error(_) -> Error("Firebase token response was malformed.")
  }
}

type FirebaseUser {
  FirebaseUser(local_id: String, display_name: option.Option(String))
}

fn firebase_user_decoder() -> decode.Decoder(FirebaseUser) {
  use local_id <- decode.field("localId", decode.string)
  use display_name <-
    decode.optional_field(
      "displayName",
      option.None,
      decode.optional(decode.string),
    )
  decode.success(FirebaseUser(local_id, display_name))
}

pub fn verify_token(token: String) -> Result(String, String) {
  case verify_identity(token) {
    Ok(#(uid, _)) -> Ok(uid)
    Error(message) -> Error(message)
  }
}

type Credentials {
  Credentials(email: String, password: String, nickname: option.Option(String))
}

pub fn handle(path: String, body: BitArray) -> AuthResult {
  case bit_array.to_string(body) {
    Error(_) -> failed("Request body is not valid UTF-8.")
    Ok(text) -> {
      case decode_credentials(text) {
        Error(message) -> failed(message)
        Ok(credentials) -> case path {
          "login" -> login(credentials.email, credentials.password)
          "register" -> {
            let nickname = credentials.nickname |> option.unwrap("") |> string.trim
            case valid_register_input(credentials.email, credentials.password, nickname) {
              Ok(Nil) -> register(credentials.email, credentials.password, nickname)
              Error(message) -> failed(message)
            }
          }
          _ -> failed("Unknown auth action.")
        }
      }
    }
  }
}

fn login(email: String, password: String) -> AuthResult {
  case firebase_config.firebase_config() {
    Error(message) -> failed(message)
    Ok(config) -> {
      let body =
        json.object([
          #("email", json.string(email)),
          #("password", json.string(password)),
          #("returnSecureToken", json.bool(True)),
        ])
        |> json.to_string
      case firebase_post(config.api_key, "/accounts:signInWithPassword", body) {
        Ok(text) -> {
          let token = extract(text, "idToken")
          case token == "" {
            True -> failed("Firebase login did not return an ID token.")
            False -> {
              let nickname =
                extract_optional(text, "displayName") |> option.unwrap("") |> string.trim
              let effective = case string.length(nickname) >= 3
                && string.length(nickname) <= 24 {
                True -> nickname
                False -> fallback_nickname(email)
              }
              case nickname == effective {
                True -> {
                  firestore.save_player(token, extract(text, "localId"), effective)
                  AuthResult(True, "Welcome back, " <> effective <> ".", effective, token)
                }
                False -> {
                  let update =
                    json.object([
                      #("idToken", json.string(token)),
                      #("displayName", json.string(effective)),
                      #("returnSecureToken", json.bool(True)),
                    ])
                    |> json.to_string
                  case firebase_post(config.api_key, "/accounts:update", update) {
                    Ok(updated) -> {
                      let final_token =
                        extract_optional(updated, "idToken") |> option.unwrap(token)
                      let final_nickname =
                        extract_optional(updated, "displayName")
                        |> option.unwrap(effective)
                      firestore.save_player(
                        final_token,
                        extract(text, "localId"),
                        final_nickname,
                      )
                      AuthResult(
                        True,
                        "Welcome back, " <> final_nickname <> ".",
                        final_nickname,
                        final_token,
                      )
                    }
                    Error(_) ->
                      failed("Your account has no valid nickname and it could not be repaired automatically.")
                  }
                }
              }
            }
          }
        }
        Error(message) -> failed(message)
      }
    }
  }
}

fn register(email: String, password: String, nickname: String) -> AuthResult {
  case firebase_config.firebase_config() {
    Error(message) -> failed(message)
    Ok(config) -> {
      let body =
        json.object([
          #("email", json.string(email)),
          #("password", json.string(password)),
          #("returnSecureToken", json.bool(True)),
        ])
        |> json.to_string
      case firebase_post(config.api_key, "/accounts:signUp", body) {
        Ok(text) -> {
          let token = extract(text, "idToken")
          case token == "" {
            True -> failed("Firebase registration did not return an ID token.")
            False -> {
              let update =
                json.object([
                  #("idToken", json.string(token)),
                  #("displayName", json.string(nickname)),
                  #("returnSecureToken", json.bool(True)),
                ])
                |> json.to_string
              case firebase_post(config.api_key, "/accounts:update", update) {
                Ok(updated) -> {
                  let final_token = extract_optional(updated, "idToken") |> option.unwrap(token)
                  let final_nickname =
                    extract_optional(updated, "displayName")
                    |> option.unwrap(nickname)
                    |> string.trim
                  case string.length(final_nickname) >= 3 && string.length(final_nickname) <= 24 {
                    True -> {
                      firestore.save_player(
                        final_token,
                        extract(text, "localId"),
                        final_nickname,
                      )
                      AuthResult(
                        True,
                        "Account created. Welcome, " <> final_nickname <> ".",
                        final_nickname,
                        final_token,
                      )
                    }
                    False ->
                      failed("Firebase created the account but did not store a valid nickname.")
                  }
                }
                Error(message) ->
                  failed("Account creation succeeded, but nickname setup failed: " <> message)
              }
            }
          }
        }
        Error(message) -> failed(message)
      }
    }
  }
}
fn firebase_post(api_key: String, path: String, body: String) -> Result(String, String) {
  let url = identity_endpoint <> path <> "?key=" <> api_key
  let assert Ok(req) = request.to(url)
  let req =
    req
    |> request.set_method(http.Post)
    |> request.prepend_header("content-type", "application/json")
    |> request.set_body(body)
  case httpc.send(req) {
    Ok(response) -> case response.status {
      200 -> Ok(response.body)
      code -> Error(firebase_error_message(code, response.body))
    }
    Error(error) -> Error("Firebase request failed: " <> string.inspect(error))
  }
}

fn firebase_error_message(code: Int, body: String) -> String {
  case json.parse(body, using: {
    use message <- decode.field("error", {
      use inner <- decode.field("message", decode.string)
      decode.success(inner)
    })
    decode.success(message)
  }) {
    Ok(message) -> "Firebase request failed (" <> int.to_string(code) <> "): " <> message
    Error(_) -> "Firebase request failed (" <> int.to_string(code) <> ")."
  }
}

fn fallback_nickname(email: String) -> String {
  let local = case string.split(email, "@") {
    [first, .._] -> string.trim(first)
    _ -> ""
  }
  case string.length(local) >= 3 && string.length(local) <= 24 {
    True -> local
    False -> "Player"
  }
}

fn decode_credentials(text: String) -> Result(Credentials, String) {
  let decoder = {
    use email <- decode.field("email", decode.string)
    use password <- decode.field("password", decode.string)
    use nickname <-
      decode.optional_field("nickname", option.None, decode.optional(decode.string))
    decode.success(Credentials(email, password, nickname))
  }
  case json.parse(text, using: decoder) {
    Ok(credentials) -> Ok(credentials)
    Error(_) -> Error("Invalid auth request.")
  }
}

fn extract(text: String, field: String) -> String {
  extract_optional(text, field) |> option.unwrap("")
}

fn extract_optional(text: String, field: String) -> option.Option(String) {
  case json.parse(text, using: {
    use value <- decode.subfield([field], decode.string)
    decode.success(value)
  }) {
    Ok(value) -> option.Some(value)
    Error(_) -> option.None
  }
}

fn valid_register_input(
  email: String,
  password: String,
  nickname: String,
) -> Result(Nil, String) {
  case string.length(string.trim(email)) >= 3 {
    False -> Error("A valid email is required.")
    True -> case string.length(password) >= 6 {
      False -> Error("Password must be at least 6 characters.")
      True -> case string.length(nickname) >= 3 && string.length(nickname) <= 24 {
        False -> Error("Nickname must be 3-24 characters.")
        True -> Ok(Nil)
      }
    }
  }
}

fn failed(message: String) -> AuthResult {
  AuthResult(False, message, "", "")
}