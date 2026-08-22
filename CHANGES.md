# Applied fixes

- Removed local client-side room creation/join/start/leave authority.
- Added server-authoritative room manager with five-player capacity and host-only start.
- Added room-state synchronization to clients.
- Prevented gameplay commands before a room has started.
- Prevented multiple started rooms from sharing the global gameplay world.
- Firebase token verification now also resolves the nickname used by the server; the client no longer sends a trusted nickname during websocket join.
- Nickname uniqueness is checked against all stored players, not only currently online players.
- Reconnect refreshes the stored server-side nickname from Firebase identity.
- Changed server loop to a 50 ms tick and scaled vehicle movement to seconds.
- Production is server-authoritative online and fills server-side inventory with warehouse capacity limits.
- Added authoritative inventory and storage data to snapshots.
- Client ignores server world snapshots while outside an active online room, preventing server entities from leaking into single-player rendering.
- Added server-derived room HUD state and storage capacity HUD data.
- Bound the server to `0.0.0.0:8765` for remote clients; production TLS should be terminated by a reverse proxy.
- Added `README.md`, `.gitignore`, and basic Gleam tests.
- Removed all `build/` and `game_client/target/` generated artifacts from the distributable ZIP.
