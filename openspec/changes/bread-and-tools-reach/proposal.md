## Why

Merchants need bread and tools, and the Renaissance needs 20 merchants. Scripted playtest bots never build a bakery or toolsmith (#71). That much is by design: the bots' kit stops at houses, farms, huts, sawmills, foresters and warehouses. But checking whether a player can reach the chain found two gaps.

- **Not every start island can hold a mine.** A mine needs at least 2 mountain tiles in its 2×2 footprint, and the market sells neither tools nor iron. Across seeds 0–49, every player home island has a mine site. But on 11 archipelago starts a second player island has mountains and no site: island 1 on seeds 5, 12, 24 and 43, and island 4 on seeds 2, 4, 13, 17, 41, 42 and 47. Two rival islands lack one too: seed 17's rival 1 and seed 30's rival 2. A town that grows from such an island can't mine there.
- **The chain is hard to see.** The house inspector lists only the current tier's needs, so a citizens' house never says that merchants want bread and tools. A locked drawer tile shows a lock and a price, not the research that unlocks it.

## What Changes

- **BREAKING (world generation):** when a town center's island has no mine site, one grass tile (or, failing that, a forest tile) beside a mountain becomes mountain, so a mine fits. Islands that already have a site are unchanged.
- The house inspector adds a key line "Next: <tier> need <goods>", naming the goods the next tier adds.
- A locked drawer tile reads "Needs <Tech>" in place of its cost.

Out of scope: teaching the scripted bots the bread and tools chains, market prices for tools or iron, and settling other islands.

## Capabilities

### New Capabilities
- (none)

### Modified Capabilities
- `world-terrain`: adds "Starter mine site".
- `platform-shells`: "Locked palette entries" names the research on the tile; "Inspector callout" adds the next tier's needs.

## Impact

- **CityCore**: world generation after each starter grove (`World+StartSites.swift`).
- **CityUI**: the house inspector's key lines and the drawer tile caption; text only, no layout change.
- **Determinism**: a start with a town-center island that lacks a mine site changes. The `DeterminismFixture` world has none, so its output and the `game-data-codegen` baseline are unchanged. The rival viability sweep runs again locally, including seeds 17 and 30, where a rival island changes.
