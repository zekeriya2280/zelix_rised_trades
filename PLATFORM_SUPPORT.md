# Cross-platform / Cross-play support

The same game protocol and authoritative Gleam server are used by desktop, Android, and Web clients.

- Desktop: native Rust HTTP + WebSocket transport.
- Android: native Rust transport; Bevy 0.19 GameActivity support.
- Web: WASM browser HTTP + WebSocket transport.
- All clients authenticate with the same server and Firebase ID-token verification.
- Room/game state remains server authoritative; clients only send player commands and consume snapshots/events.
- A desktop, Android, and Web player can occupy the same room because their network messages use the same `ClientMessage` / `ServerMessage` protocol.

Firebase configuration discovery on the server:
1. `firebase_config.json`
2. `google-services.json`

`google-services.json` is the Android app artifact; Web Firebase uses a config object. The server extracts the API key without hardcoding it.

Generated `build/`, `game_client/target/`, Android `jniLibs/`, and APK outputs are intentionally omitted from source ZIPs and are recreated by builds.
