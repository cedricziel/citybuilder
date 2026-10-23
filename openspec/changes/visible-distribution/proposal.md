## Why

The owner wants to watch goods move: from one workshop to the next, then to a market, and from the market to the houses, carried by people on foot and with carts. Today the town hides most of that:

- Carriers only run producer → storage, storage → consumer, and producer → construction site. A mill's flour always detours through a warehouse before it reaches the bakery.
- Houses never receive anything. Every 100 ticks they draw food, planks, bread and tools straight out of any goods buffer on their road network (`World.consume`). Their needs count as met while such a buffer holds the good (`hasGoodInReach`), however far away it is.
- Everyone walks with one unit. There are no carts, so a busy town is a crowd of single sacks.

## What Changes

This change comes in three milestones. Each is its own PR, with its own spec delta, tests, determinism baseline and balance sweep. They ship in the order 1, 3, 2: handcarts do not depend on the market, and the market needs its marketplace canvas first.

1. **Direct chain hops.** A producer's output goes straight to the nearest consumer on its road network that is short of it, such as mill → bakery or sawmill → toolsmith. When no consumer is short, it goes to storage as today. Waiting construction sites keep first claim. Supply carriers count these deliveries, so a consumer is never served twice.
2. **The market as the hub for house goods.**
   - Finished house goods (food, planks, bread, tools and the culture's luxury) gather at market hubs: the town center and a new marketplace building, which ship together.
   - Market porters walk them to the houses within a radius.
   - Each house keeps a small stock per need. Consumption draws from that stock, so a need is met by real deliveries rather than by a warehouse somewhere on the road network.
   - The stock covers the gap between porter visits, so satisfaction does not flicker.
   - There is no warehouse fallback. A house out of every hub's reach shows "No market in reach", like a house without a road.
   - Rivals follow the same rules.
3. **Handcarts.** A long or bulk haul goes on a handcart that carries 4 units: one person pushing a two-wheeled cart that fits a road tile, at walking speed. Short or small hauls stay on foot. Which one is decided from the road distance and the amount ready to go.

The distribution numbers (hub radius, porter count, basket size, cart thresholds, house stock) live in the game-data packs so designer2 can tune them.

Out of scope:
- Ox carts and wagons;
- carts for porters;
- changing ships or caravans;
- player control over routing.

## Capabilities

### New Capabilities
- (none)

### Modified Capabilities
- `warehouses-and-logistics`:
  - Milestone 1 adds "Producers deliver to short consumers".
  - Milestone 3 adds "Handcarts carry long and bulk hauls".
  - Milestone 2 modifies the building-issues requirement: a house out of every hub's reach reports "No market in reach", after no road.
- `population-and-needs`, milestone 2:
  - "Town center supplies house needs" and "Houses consume food and planks" are modified to read from the house's own stock.
  - "Market porters supply houses" is added.
- `rendering-2_5d`, milestones 2 and 3: porters and handcarts render.
- `buildings-and-construction`, milestone 2: "Marketplace" is added.

## Impact

- **CityCore:**
  - `Carrier` gains mission cases and a vehicle; `HousePopulation` gains a stock.
  - The carrier, supply and population systems change.
  - Hub restocking and porter dispatch are new.
  - Saves need migration for in-flight carriers and house stock.
  - Every milestone moves the determinism baseline on purpose.
- **Economy balance:** milestone 2 changes how fast houses are supplied, and where they can be supplied at all. It has to be tuned together with designer2's pacing change and checked with the PlayerBot sweeps (first-hour solvency, rival viability, mid-game pacing) before and after. Acceptance: the first-hour guided sweep stays at 0 of 20 bankruptcies.
- **Rival towns:** they follow the same rules. Their AI already places the town center first; its house placement has to stay inside a hub's radius, and it builds marketplaces. Acceptance: the rival-viability sweep stays green.
- **Game data:** hub buildings gain a `hub` block, and a `Logistics` item holds the cart and house-stock numbers.
- **Buildings:** a new `marketplace` building, with its own canvas, cost and research gate.
- **Art:**
  - Two new figure families need the canvas first: market porters (milestone 2) and the handcart (milestone 3).
  - Each look is 4 facings × 8 frames at both scales, 64 PNGs, about 100–140 KB of Kit.atlas.
- **CityRender2D:** `CarrierRendering` picks the look from the mission and the vehicle, and draws porters on their way back with empty baskets.
