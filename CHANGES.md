# Applied fixes

## Security review pass (this revision)

- **Actually redacted** the live Firebase Android API key that was still present verbatim in `android/app/google-services.json` (a previous packaging pass claimed this was done, but the real key was still committed). The file now matches `google-services.example.json` with placeholder values. **If this key was ever pushed to a public repository or shared, rotate it in the Firebase console — replacing the file alone does not invalidate an already-leaked key.**
- Made the auth endpoints' CORS policy configurable: `/auth/login` and `/auth/register` previously always sent `Access-Control-Allow-Origin: *`. They now read an `ALLOWED_ORIGIN` environment variable (falling back to `*` for local dev) via a new `server/router.allowed_origin/0` helper backed by the existing `game_server_os_ffi:get_env/1` FFI. Set `ALLOWED_ORIGIN` in production to your real Web origin.

## Packaging / hygiene pass

- Removed leftover AI-authoring citation artifacts (`citeturn...`) from `README.md`.
- Added `google-services.example.json` as a template, matching the existing `firebase_config.example.json` / `game_config.example.json` pattern.
- Added `google-services.json`, `android/app/google-services.json`, and `firebase_config.json` to `.gitignore`.
- Added `LICENSE` (MIT) — confirm this is the license you actually want before publishing.
- Added a GitHub Actions workflow (`.github/workflows/ci.yml`) running `gleam test` / `gleam check` for the server and `cargo fmt` / `clippy` / `check` for the client.
- This distributable ZIP excludes the generated `build/` and `game_client/target/` directories (per `.gitignore`); they are recreated automatically by `gleam build` / `cargo build`.

Known remaining gap: unit test coverage on the Gleam server is still limited to a handful of pure/public functions (`initial_world`, Firebase decode helpers); most game-rule logic in `game_server.gleam` is private to the module and would need either exposed test seams or in-module tests to cover directly.

## Rust client compile errors fixed

`cargo run` in `game_client` failed with 4 errors:

- `use of undeclared type LobbyPanel` (×3 in `src/network/websocket.rs`) — `LobbyPanel` is defined in `frontend.rs` but wasn't in that file's `use crate::frontend::{...}` import list. Added it.
- `cannot find value cleanup_server_entities_system` (`src/network/mod.rs`) — this system was registered in the `NetworkPlugin` system schedule but was never defined anywhere in the crate. Its job (despawning stale server-owned entities not present in the latest snapshot) is already performed inline at the end of `apply_snapshot_system` in `websocket.rs`, so the dangling reference was a leftover from an earlier refactor. Removed it from the schedule; no behavior was lost.

Also scanned the whole `game_client` crate for any other dangling `add_systems` references or unimported public types from `frontend.rs` — none found.

- Removed local client-side room creation/join/start/leave authority.
- Added server-authoritative room manager with five-player capacity and host-only start.
- Added room-state synchronization to clients.
- Prevented gameplay commands before a room has started.
- Prevented multiple started rooms from sharing the global gameplay world.
- Firebase token verification now also resolves the nickname used by the server; the client no longer sends a trusted nickname during websocket join.
- Nickname uniqueness is enforced for currently connected server sessions; persistent nickname uniqueness is intentionally not claimed by the runtime server.
- Reconnect refreshes the stored server-side nickname from Firebase identity.
- Changed server loop to a 50 ms tick and scaled vehicle movement to seconds.
- Production is server-authoritative online and fills server-side inventory with warehouse capacity limits.
- Added authoritative inventory and storage data to snapshots.
- Client ignores server world snapshots while outside an active online room, preventing server entities from leaking into single-player rendering.
- Added server-derived room HUD state and storage capacity HUD data.
- Bound the server to `0.0.0.0:8765` for remote clients; production TLS should be terminated by a reverse proxy.
- Added `README.md`, `.gitignore`, and basic Gleam tests.
- Removed generated `build/`, `game_client/target/`, and Android native build outputs from the distributable ZIP.
- Kept Firestore writes as best-effort account/room metadata only; authoritative live room state stays in the server process.

- Fixed Online lobby panel visibility so only one of Choice/CreateRoom/EnterRoom is visible at a time.
- Online main panel now exposes Create Room, Enter Room, Settings, and Main Menu.
- Added server-side open-room listing for Enter Room.
- Increased client authoritative snapshot polling to 10 Hz.
- Reset match world/economy at room start and when the final player leaves.
- Added cleanup of server-owned ECS entities when leaving online mode.
- Added CORS support for Web auth requests.
- Added an Android GameActivity Gradle host and asset packaging.

## Deep fix pass — 2026-08-26

- Reset WebSocket connection state on server/protocol errors so reconnect cannot deadlock in `connecting`.
- Added explicit disconnect signalling for native/WASM auth-send failures.
- Removed the single-started-room server restriction. Room start/reset now scopes entity cleanup to that room's players.
- Scoped world snapshots to the requesting player's room instead of exposing unrelated room entities.
- Persist room player/start lifecycle metadata to Firestore on create/join/start/leave.
- Added Firebase environment-variable configuration (`FIREBASE_API_KEY`, `FIREBASE_PROJECT_ID`).
- Hardened Android release builds to require an explicit server URL; debug retains emulator defaults.
- Hardened Web build URL configuration and verification scripts.
- Added a regression test for the WebSocket connection-error state machine.
