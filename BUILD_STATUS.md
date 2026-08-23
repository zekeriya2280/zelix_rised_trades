# Build Status

- Firebase nested `accounts:lookup` parsing fixed (`users[0].localId`, `users[0].displayName`).
- Firebase config auto-discovery added (`firebase_config.json` then `google-services.json`).
- Desktop/Android native networking and Web/WASM browser networking are separated with target-specific dependencies.
- Shared protocol remains common to all clients for cross-play.
- Added Firestore persistence for player registrations (`players` collection) and created rooms (`rooms` collection) via the REST API. A shared `server/firebase_config` module now exposes both `api_key` and the project id.
- Android GameActivity support enabled for Bevy 0.19.
- Web Trunk entry point included.
- Generated `build/` and `game_client/target/` are intentionally omitted from the ZIP.

Live compiler/test execution was not available in the assembly environment because Rust/Cargo and Gleam/Erlang executables are not installed.
