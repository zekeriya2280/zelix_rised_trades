# Online architecture

The Online flow is now single-panel: Online -> Create Room / Enter Room / Settings / Main Menu. Create Room and Enter Room are mutually exclusive panels.

The client requests authoritative world snapshots every 100 ms (10 Hz). Lobby state is refreshed when the connection is established, after lobby commands, and during a 15-second keep-alive. This keeps Android/Web/Desktop clients responsive without requiring a socket broadcast registry.

The server remains authoritative for economy, room membership, room start/leave, building placement, factory selection, vehicles, and the world tick. A started room is the only active game room. Starting a room resets the match world and the participating players' match economy. When the final participant leaves, the match world is cleared.

Firestore writes are best-effort account/room metadata. They are not used as the authoritative runtime game state.
