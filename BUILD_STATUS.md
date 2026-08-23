# Build Status

- Firebase nested `accounts:lookup` parsing fixed (`users[0].localId`, `users[0].displayName`).
- Firebase config auto-discovery added (`firebase_config.json` then `google-services.json`).
- Desktop/Android native networking and Web/WASM browser networking are separated with target-specific dependencies.
- Shared protocol remains common to all clients for cross-play.
- Added best-effort Firestore account/room metadata writes via the REST API. Runtime multiplayer state remains authoritative in the server process; it is not restored from Firestore.
- Android GameActivity support enabled for Bevy 0.19.
- Web Trunk entry point included.
- Generated `build/`, `game_client/target/`, Android native libraries, and APK outputs are intentionally omitted from the ZIP.

Live compiler/test execution was not available in the assembly environment because Rust/Cargo and Gleam/Erlang executables are not installed.

- Online lobby now uses one visibility authority: Online -> Create Room / Enter Room / Settings / Main Menu, with Create and Enter panels mutually exclusive.
- Enter Room receives a server-generated list of all joinable rooms.
- Authoritative lobby/world snapshots are requested at 10 Hz instead of every 2 seconds.
- Match world/economy is reset when a room starts; final room departure clears the match state.
- Server-owned client entities are despawned when leaving online gameplay.
- Added Android GameActivity Gradle host project and asset packaging.
- Added CORS handling for browser auth endpoints.
