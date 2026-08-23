# Online architecture

The Online flow is now single-panel: Online -> Create Room / Enter Room / Settings / Main Menu. Create Room and Enter Room are mutually exclusive panels.

The client polls lobby state and authoritative world snapshots at 10 Hz. This avoids stale 2-second updates and makes Android/Web/Desktop clients converge quickly even without a socket broadcast registry.

The server remains authoritative for economy, room membership, room start/leave, building placement, factory selection, vehicles, and the world tick. A started room is the only active game room. Starting a room resets the match world and the participating players' match economy. When the final participant leaves, the match world is cleared.

Firestore writes are best-effort account/room metadata. They are not used as the authoritative runtime game state.
