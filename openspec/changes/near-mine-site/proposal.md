## Why

On the archipelago the player's home town center is often far from a mine site. #170 guarantees a site somewhere on the home island, not near the town center. Measured on `main` as road tiles from the town center's starter road ring to the nearest site a mine could take once Mining is researched, for archipelago seeds 0–29:

| | |
|---|---|
| Median | 13.5 |
| Range | 1–35 |
| Within 10 road tiles | 11 of 30 |
| Seeds 3, 17 and 28 | 35, 31 and 30 |

The single-island map holds one at 1 road tile on every seed. Without a mine there are no tools, so no merchants and no Renaissance. The #242 overlay shows valid sites only within 6 tiles of the cursor while the mine is armed, so it cannot point at a site 20 tiles away (#222).

## What Changes

- World generation guarantees a mine site whose side touches a tile **at most 10 road tiles** from each town center's road ring. Road tiles are counted over land, through forest and mountain, as the player would lay them.
- **When no site is that near,** generation raises a near 3×3 rock outcrop: the nearest square of grass (then grass or forest) that lies outside the start area and off the road ring. A 3×3 keeps a crag in its middle; a 2×2 is all edge and draws as scree, which reads as grass with pebbles. The start area's fairness counts (grass, mountain share, hut site) are unchanged because the outcrop lies outside it.
- The #170 island-wide raise stays as the fallback, for islands too small for a near outcrop. There the near-site guarantee does not hold: the island keeps (or gets) a mine site, which may lie farther out. On seeds 0–29 of both layouts no town center needs it: all 180 have a site within 10 road tiles.
- **Measured after:** every archipelago seed 0–29 has a site within 10 road tiles; 19 of the 30 home islands gained an outcrop. Every outcrop sits 6 road tiles out, the nearest square outside the start area. Seeds that already had a near site keep their terrain.
- Rival islands get the same rule, since town centers are seated before owners are assigned.
- **(b), relying on the overlay alone, is not enough.** It searches 6 tiles around the cursor, and players have no reason to sweep the cursor across an island. The overlay stays as the way to find the exact plot.

## Capabilities

### New Capabilities
- (none)

### Modified Capabilities
- `world-terrain`: "Starter mine site" now guarantees a site near the town center, with a near outcrop when none is near.

## Impact

- **Code:** `World+StartSites.swift` (`raiseStarterMineSite`, `roadSteps(fromRingOf:)`, `sideNeighbours(of:at:)`). Tests: `StarterMineSiteTests.swift`.
- **World generation changes on purpose.** Archipelago games on 19 of 30 measured seeds get a 3×3 outcrop on the home island, and some rival islands do too. Single-island games are unchanged.
- **Determinism fixture:** `DeterminismFixture` (archipelago seed 0xC17B, 6000 ticks, `SWIFT_DETERMINISTIC_HASHING=1`) changes on purpose, from `8bfb9c41…` on `main` to `0e0e0f96…`; two runs of the new output match. The cross-platform gate compares macOS with Linux at the same commit, so it is unaffected. The committed baselines under `openspec/changes/game-data-codegen/baseline/` and `tier-needs-data/baseline/` are historical parity records whose tasks are complete; they are left as they are and say so.
- **Saves:** none. Only new games change.
