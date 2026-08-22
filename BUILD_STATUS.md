# Verification status

The ZIP was checked for archive integrity and for accidental inclusion of generated `build/` / `target/` output.

Static checks completed:

- Client/server websocket message names and lobby fields were aligned.
- Firebase join flow uses server-side token identity lookup.
- Client-side local room mutation code was removed.
- Server-only world commands are gated behind an active started room.
- Authoritative inventory/storage fields are present in snapshots and consumed by the client.
- Server-owned entities are reconciled by ID.

Full `cargo check` / `cargo test` and `gleam test` / `gleam check` could not be executed in the packaging environment because Rust/Cargo, Gleam, and Erlang/OTP executables are not installed there. The source package itself is complete and excludes generated build products.
