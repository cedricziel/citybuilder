## MODIFIED Requirements

### Requirement: Manifest actions
A `ManifestAction` SHALL be exactly one of two cases: `.loadUpTo(good: Good, qty: Int)` or `.unloadUpTo(good: Good, qty: Int)`. Ships executing a manifest at a port MUST apply actions in declared order, each action MUST be capped by the ship's free capacity (for loads) or current cargo of that good (for unloads), and each action MUST further be capped by what the port's goods buffer can provide or, for that good, accept.

#### Scenario: Load action up to ship capacity
- **WHEN** a ship with 20 units of free capacity executes `.loadUpTo(wood, 50)` at a port holding 70 wood
- **THEN** the ship's wood cargo increases by 20 and the port's wood stock decreases by 20

#### Scenario: Load action up to port stock
- **WHEN** a ship with 60 units of free capacity executes `.loadUpTo(wood, 50)` at a port holding 30 wood
- **THEN** the ship's wood cargo increases by 30 and the port's wood stock decreases by 30

#### Scenario: Unload action up to port free capacity
- **WHEN** a ship carrying 40 wood executes `.unloadUpTo(wood, 50)` at a port with room for 25 more wood
- **THEN** the ship's wood cargo decreases by 25 and the port's wood stock increases by 25

#### Scenario: Manifest actions execute in declared order
- **WHEN** a ship carrying 100 planks docks at a port holding 70 wood whose manifest is `[.unloadUpTo(planks, 50), .loadUpTo(wood, 50)]`
- **THEN** the unload runs first, freeing ship capacity, and the load proceeds against the freed capacity in the same docking turn
