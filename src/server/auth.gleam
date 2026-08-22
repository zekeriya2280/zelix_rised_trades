import gleam/bit_array
import gleam/dynamic/decode
import gleam/http
import gleam/http/request
import gleam/httpc
import gleam/int
import gleam/json
import gleam/option
import gleam/result
import gleam/string

const identity_endpoint = "https://identitytoolkit.googleapis.com/v1"

pub type AuthResult { AuthResult(ok: Bool, message: String, nickname: String, token: String) }


pub fn verify_identity(token: String) -> Result(#(String, String), String) {
  case api_key() {
    "" -> Error("FIREBASE_WEB_API_KEY is not configured on the server.")
    _ -> {
      let body = json.object([#("idToken", json.string(token))]) |> json.to_string
      case firebase_post("/accounts:lookup", body) {
        Ok(text) -> {
          let uid = extract_optional(text, "localId")
          let nickname = extract_optional(text, "displayName")
          case uid {
            option.Some(id) -> {
              let name = nickname |> option.unwrap("") |> string.trim
              case string.length(name) >= 3 && string.length(name) <= 24 {
                True -> Ok(#(id, name))
                False -> Error("Firebase account does not have a valid nickname.")
              }
            }
            option.None -> Error("Firebase token did not contain a user id.")
          }
        }
        Error(message) -> Error(message)
      }
    }
  }
}

pub fn verify_token(token: String) -> Result(String, String) {
  case verify_identity(token) { Ok(#(uid, _)) -> Ok(uid) Error(message) -> Error(message) }
}

type Credentials { Credentials(email: String, password: String, nickname: option.Option(String)) }

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

@external(erlang, "game_server_os_ffi", "get_env")
fn get_env_ffi(key: String) -> Result(String, Nil)

fn api_key() -> String { get_env_ffi("FIREBASE_WEB_API_KEY") |> result.unwrap("") }

fn login(email: String, password: String) -> AuthResult {
  case api_key() {
    "" -> failed("FIREBASE_WEB_API_KEY is not configured on the server.")
    _ -> {
      let body = json.object([
        #("email", json.string(email)), #("password", json.string(password)), #("returnSecureToken", json.bool(True)),
      ]) |> json.to_string
      case firebase_post("/accounts:signInWithPassword", body) {
        Ok(text) -> {
          let token = extract(text, "idToken")
          let nickname = extract_optional(text, "displayName") |> option.unwrap(email)
          AuthResult(True, "Welcome back, " <> nickname <> ".", nickname, token)
        }
        Error(message) -> failed(message)
      }
    }
  }
}

fn register(email: String, password: String, nickname: String) -> AuthResult {
  case api_key() {
    "" -> failed("FIREBASE_WEB_API_KEY is not configured on the server.")
    _ -> {
      let body = json.object([
        #("email", json.string(email)), #("password", json.string(password)), #("returnSecureToken", json.bool(True)),
      ]) |> json.to_string
      case firebase_post("/accounts:signUp", body) {
        Ok(text) -> {
          let token = extract(text, "idToken")
          let update = json.object([
            #("idToken", json.string(token)), #("displayName", json.string(nickname)), #("returnSecureToken", json.bool(True)),
          ]) |> json.to_string
          case firebase_post("/accounts:update", update) {
            Ok(updated) -> AuthResult(True, "Account created. Welcome, " <> nickname <> ".", extract_optional(updated, "displayName") |> option.unwrap(nickname), extract_optional(updated, "idToken") |> option.unwrap(token))
            Error(_) -> AuthResult(True, "Account created. Welcome, " <> nickname <> ".", nickname, token)
          }
        }
        Error(message) -> failed(message)
      }
    }
  }
}

fn firebase_post(path: String, body: String) -> Result(String, String) {
  let url = identity_endpoint <> path <> "?key=" <> api_key()
  let assert Ok(req) = request.to(url)
  let req = req |> request.set_method(http.Post) |> request.prepend_header("content-type", "application/json") |> request.set_body(body)
  case httpc.send(req) {
    Ok(response) -> case response.status {
      200 -> Ok(response.body)
      code -> Error("Firebase request failed (" <> int.to_string(code) <> "): " <> response.body)
    }
    Error(error) -> Error("Firebase request failed: " <> string.inspect(error))
  }
}

fn decode_credentials(text: String) -> Result(Credentials, String) {
  let decoder = {
    use email <- decode.field("email", decode.string)
    use password <- decode.field("password", decode.string)
    use nickname <- decode.optional_field("nickname", option.None, decode.optional(decode.string))
    decode.success(Credentials(email, password, nickname))
  }
  case json.parse(text, using: decoder) {
    Ok(credentials) -> Ok(credentials)
    Error(_) -> Error("Invalid auth request.")
  }
}

fn extract(text: String, field: String) -> String { extract_optional(text, field) |> option.unwrap("") }
fn extract_optional(text: String, field: String) -> option.Option(String) {
  case json.parse(text, using: {
    use value <- decode.subfield([field], decode.string)
    decode.success(value)
  }) {
    Ok(value) -> option.Some(value)
    Error(_) -> option.None
  }
}

fn valid_register_input(email: String, password: String, nickname: String) -> Result(Nil, String) {
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

fn failed(message: String) -> AuthResult { AuthResult(False, message, "", "") }
