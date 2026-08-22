# Zelix Rised Trades

Server-authoritative Gleam/Mist multiplayer server with a Bevy client.

## Structure

- `src/`: Gleam game server and Firebase authentication.
- `game_client/`: Bevy client.
- `manifest.toml` / `game_client/Cargo.lock`: locked dependency metadata.

## Environment

Server:

```powershell
$env:FIREBASE_WEB_API_KEY="YOUR_FIREBASE_WEB_API_KEY"
```

Client:

```powershell
$env:GAME_SERVER_URL="http://127.0.0.1:8765"
```

For a remote deployment, point `GAME_SERVER_URL` at the server host. The server binds to `0.0.0.0:8765`; put TLS (`wss://`) in front of it with a reverse proxy for production.

## Multiplayer flow

1. Firebase token is verified by the server.
2. The server obtains the nickname from Firebase rather than trusting the client name field.
3. Room creation, join, start and leave are server-authoritative.
4. A room is limited to five players.
5. Building, vehicle, factory-product and production state are authoritative on the server once the room starts.
6. Inventory and warehouse capacity are included in authoritative snapshots.
7. Only one room may be started at a time; this avoids cross-room state leakage while waiting lobbies remain independent.
8. The Bevy client only reconciles server-owned entities while in an active online room.

## Development

Do not commit or package `build/` or `game_client/target/`. They are generated build outputs and can be recreated locally.
