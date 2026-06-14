# TODO

## Truck Depot + Truck Screen (Task 3)
- [ ] Add persistent Truck Depot ownership (use `purchasedBuildings['Truck Depot']` or dedicated field) to `GameState` + engine API `hasTruckDepot()`.
- [ ] Enforce rule: **cannot buy Truck Depot before owning at least one Warehouse**.
- [ ] Implement TruckSystem shipment gating: **no truck operations without Truck Depot**.
- [ ] Add `TruckScreen` page.
- [ ] Add Warehouse -> Truck navigation button.
- [ ] In `TruckScreen`, allow player to select:
  - [ ] fromWarehouse
  - [ ] toCity (if cities exist; otherwise add minimal city support or UI workaround)
  - [ ] resource type + amount (slider)
  - [ ] distance/level slider that affects fee
- [ ] Implement “Start” action:
  - [ ] creates/assigns a truck (or uses available idle trucks)
  - [ ] performs shipment from selected warehouse to destination warehouse (or create destination warehouse mapping)
- [ ] Track and display per-truck shipment info (distance, fee, from/to, resource, amount) in a Card list.

- [ ] Add tests/manual checklist in app behavior.


