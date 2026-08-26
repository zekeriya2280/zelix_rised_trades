import gleam/bit_array
import gleam/dynamic/decode
import gleam/json
import gleam/option

@external(erlang, "game_server_os_ffi", "read_project_file")
fn read_project_file(name: String) -> Result(BitArray, Nil)

@external(erlang, "game_server_os_ffi", "get_env")
fn get_env(name: String) -> Result(String, Nil)

/// Shared Firebase server configuration. Authentication (identitytoolkit),
/// Firestore, and any other Firebase REST calls all read the same values
/// (`apiKey` + project id) from either `firebase_config.json` (Web config
/// object) or `google-services.json` (Android artifact).
pub type FirebaseConfig {
  FirebaseConfig(api_key: String, project_id: String)
}

pub fn firebase_config() -> Result(FirebaseConfig, String) {
  // Production deployments should prefer environment variables so secrets/config
  // do not need to be committed to the repository. Files remain a convenient
  // local-development fallback.
  case get_env("FIREBASE_API_KEY") {
    Ok(api_key) ->
      case get_env("FIREBASE_PROJECT_ID") {
        Ok(project_id) ->
          case api_key == "" || project_id == "" {
            True -> file_fallback()
            False -> Ok(FirebaseConfig(api_key, project_id))
          }
        Error(_) -> file_fallback()
      }
    Error(_) -> file_fallback()
  }
}

fn file_fallback() -> Result(FirebaseConfig, String) {
  case read_project_file("firebase_config.json") {
    Ok(bytes) -> decode_firebase_config(bytes)
    Error(_) -> case read_project_file("google-services.json") {
      Ok(bytes) -> decode_google_services_config(bytes)
      Error(_) ->
        Error(
          "Firebase configuration not found. Set FIREBASE_API_KEY and FIREBASE_PROJECT_ID, or provide firebase_config.json/google-services.json.",
        )
    }
  }
}

fn decode_firebase_config(bytes: BitArray) -> Result(FirebaseConfig, String) {
  case bit_array.to_string(bytes) {
    Error(_) -> Error("Firebase configuration is not valid UTF-8.")
    Ok(text) ->
      case json.parse(text, using: {
        use api_key <- decode.field("apiKey", decode.string)
        use project_id <- decode.field("projectId", decode.string)
        decode.success(FirebaseConfig(api_key, project_id))
      }) {
        Ok(config) -> Ok(config)
        Error(_) ->
          Error(
            "firebase_config.json is invalid. Required fields: apiKey, projectId.",
          )
      }
  }
}

type GoogleProject {
  GoogleProject(project_id: String)
}

type GoogleClient {
  GoogleClient(api_key: option.Option(String))
}

fn decode_google_services_config(bytes: BitArray) -> Result(FirebaseConfig, String) {
  case bit_array.to_string(bytes) {
    Error(_) -> Error("google-services.json is not valid UTF-8.")
    Ok(text) ->
      case json.parse(text, using: {
        use project <- decode.field("project_info", google_project_decoder())
        use clients <- decode.field("client", decode.list(google_client_decoder()))
        decode.success(#(project, clients))
      }) {
        Ok(#(project, clients)) -> find_google_key(project.project_id, clients)
        Error(_) ->
          Error("google-services.json is invalid or contains no client array.")
      }
  }
}

fn google_project_decoder() -> decode.Decoder(GoogleProject) {
  use project_id <- decode.field("project_id", decode.string)
  decode.success(GoogleProject(project_id))
}

fn google_client_decoder() -> decode.Decoder(GoogleClient) {
  use keys <-
    decode.optional_field("api_key", [], decode.list(api_key_decoder()))
  case keys {
    [key, .._] -> decode.success(GoogleClient(option.Some(key)))
    [] -> decode.success(GoogleClient(option.None))
  }
}

fn api_key_decoder() -> decode.Decoder(String) {
  use current_key <- decode.field("current_key", decode.string)
  decode.success(current_key)
}

fn find_google_key(
  project_id: String,
  clients: List(GoogleClient),
) -> Result(FirebaseConfig, String) {
  case clients {
    [client, ..rest] -> case client.api_key {
      option.Some(key) -> Ok(FirebaseConfig(key, project_id))
      option.None -> find_google_key(project_id, rest)
    }
    [] -> Error("google-services.json contains no Firebase API key.")
  }
}