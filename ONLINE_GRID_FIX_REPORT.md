# Online/Grid/Rendering Fix Report

## Implemented

1. Server vehicle movement is now based on a server-authoritative 4-way grid route instead of direct diagonal movement.
2. Route search uses deterministic breadth-first shortest-path traversal on the same 100x100, 20-unit grid used by the client.
3. Diagonal neighbors are impossible: only +X, -X, +Y and -Y transitions are generated.
4. Terrain, sea and mountain cells are excluded from road routing.
5. Building 2x2 footprints are excluded from road routing.
6. Source and destination buildings are exited/entered through walkable boundary cells.
7. The server stores the complete vehicle path and the next waypoint index.
8. Vehicle snapshots now transmit the authoritative path and path index.
9. Clients no longer recalculate online vehicle roads from local terrain.
10. Clients render the exact path received from the server.
11. Clients place online vehicles at the authoritative grid position and follow the server path for facing/visual direction.
12. Completed server vehicles are removed instead of accumulating forever.
13. Online snapshots continue to expose every entity owned by players in the same room, so all room members render the same shared world.
14. Server path obstruction is scoped to the current room; buildings from another room cannot silently block a route.
15. Server building-distance validation is scoped to the current room for the same isolation reason.
16. Terrain/grid/building alignment remains based on the same 20-unit grid and 2x2 building footprint.
17. Terrain is moved to z=-20 and the grid to z=-10 so the grid is visibly above terrain.
18. Road layer is z=0 and vehicle layer is z=5; buildings remain z=20, giving stable ordering.
19. Grid line thickness/opacity was increased so the grid is visible during gameplay.
20. Added a protocol round-trip test covering authoritative vehicle path data and retained finite-value validation for all path coordinates.

## Architecture after the fix

SERVER
- owns vehicle position
- owns shortest grid route
- owns current path index
- owns room-visible world state

CLIENT
- renders the server path
- renders the server vehicle position
- keeps OwnerId for interaction/permission decisions
- does not invent a different online path

## Verification note

The archive was inspected and patched statically. This runtime does not provide the Cargo/Gleam compiler binaries, so a final `cargo test` / `gleam test` execution could not be performed inside this session. The source/protocol consistency was checked by static inspection.
