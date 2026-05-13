## ADDED Requirements

### Requirement: Ghost preview surfaces material cost

When a build tool is armed and the player is hovering over a tile, the ghost preview SHALL expose the building's `materialCost` and the current available amount on the placement's island via a `costBreakdown: [Good: (need: Int, have: Int)]?` payload. The CityUI cost-breakdown row MUST render one chip per required good, showing the per-good `need / have` pair. Goods where `have < need` MUST render in a red foreground color. Tools whose armed building has empty `materialCost` (road, demolish, inspect) MUST produce a nil `costBreakdown` and hide the row entirely.

#### Scenario: Ghost preview surfaces material cost when build tool is armed

- **WHEN** the player arms the sawmill build tool and hovers over a buildable tile
- **THEN** the ghost preview returns a `costBreakdown` with entries for `.wood` (need: 4) and `.planks` (need: 1)

#### Scenario: Cost breakdown reads available stock from current island

- **WHEN** the placement anchor falls on Island #1 and Island #1 holds 2 wood and 3 planks
- **THEN** the `have` values in the breakdown are 2 wood and 3 planks (not the global total across islands)

#### Scenario: Shortfall good highlights red

- **WHEN** the cost breakdown's `(need, have)` for a good has `have < need`
- **THEN** the chip's text color is red (or the platform's equivalent destructive style)

#### Scenario: Free-of-materials tool has no cost row

- **WHEN** the player arms the road build tool
- **THEN** `costBreakdown` is nil and the cost-breakdown row is not rendered
