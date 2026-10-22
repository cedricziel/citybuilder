## Why

Merchants need bread and tools, and the Renaissance needs 20 merchants. Scripted playtest bots never build a bakery or toolsmith (#71). That much is by design: the bots' kit stops at houses, farms, huts, sawmills, foresters and warehouses. But checking whether a player can reach the chain found two gaps.

- **Tools can be out of reach.** A mine needs at least 2 mountain tiles in its 2×2 footprint. On 4 of 50 archipelago starts (seeds 5, 12, 24 and 43), the home island has 27–39 mountain tiles but no two in any 2×2 square, so no mine fits. The market doesn't sell tools or iron. Without settling another island, these towns can never have merchants or reach the Renaissance.
- **The chain is hard to see.** The house inspector lists only the current tier's needs, so a citizens' house never says that merchants want bread and tools. A locked drawer tile shows a lock and a price, not the research that unlocks it.

## What Changes

- **BREAKING (world generation):** when the player's home island has no mine site, one grass or forest tile beside a mountain becomes mountain, so a mine fits. Islands that already have a site are unchanged.
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

- **CityCore**: world generation after the starter grove (`World+StartSites.swift`).
- **CityUI**: the house inspector's key lines and the drawer tile caption; text only, no layout change.
- **Determinism**: any start whose home island lacks a mine site changes, so the `DeterminismFixture` output and the `game-data-codegen` baseline may change. The rival viability sweep runs again locally.
