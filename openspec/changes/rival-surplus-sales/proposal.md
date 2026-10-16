## Why

By year 15 the median rival holds about 200 planks it no longer needs: its sawmills keep turning wood into planks, and only debt or a full town center makes it sell (#112). In towns whose stores fill up, the surplus leaves no room for the farms' food.

## What Changes

- **BREAKING (rival AI):** a rival whose goods buffers together have fewer than 40 units of room sells planks, then wood, above 60 units at its market, one good per turn, within its seasonal sell limits.

Out of scope: limiting sawmills or huts, demolishing rival buildings, and the building cap.

## Capabilities

### New Capabilities
- (none)

### Modified Capabilities
- `rival-towns`: "Rival market trades" gains a fourth case, "Sell surplus".

## Impact

- **CityCore**: `Systems/RivalSystem.swift` (room across the rival's stores) and `Systems/RivalSystem+Market.swift` (the sale).
- **Determinism**: archipelago games with rivals play out differently, so the `DeterminismFixture` output and the `game-data-codegen` baseline change on purpose.
