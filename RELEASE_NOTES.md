# Zelix Rised Trades — strengthened ZIP

## Applied improvements

- World snapshots are requested at 10 Hz (100 ms) instead of 1 Hz.
- WebSocket keep-alive is separated from gameplay replication and runs every 15 seconds.
- Disconnect handling clears the authenticated player/session state and pending authoritative world data before reconnect.
- Server rejects NaN/invalid floating-point coordinates and vehicle speeds.
- Online nickname collision checks now apply to currently connected players, matching the multiplayer requirement.
- Room-start validation has an explicit single-authoritative-match invariant so concurrent matches cannot corrupt the shared world state.
- Rust protocol tests now cover non-finite vehicle data and safe room defaults.
- Project documentation was synchronized with the actual runtime behavior.
- Added `scripts/verify.ps1` for cargo/gleam/asset checks on a properly provisioned development machine.
- Secret scan completed with no embedded Firebase private keys or API-key-looking credentials in source/config examples.

## Verification limitation

The packaging environment does not contain Rust/Cargo, Gleam/Erlang, or Android build tooling, so this archive was not compiler-verified inside the packaging environment. The verification script is included so the project can be checked directly on a development machine.
