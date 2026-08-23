# Applied fixes

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
