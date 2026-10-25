## Context

Merchants need food, planks, bread, tools and their culture's luxury. The bread and tools chains each take three buildings, the luxury two, and the PlayerBot's mid-game kit builds all of them from the same trigger (6 houses), so the first merchant, 20 merchants and the Renaissance arrive close together (#186). The owner wants deeper chains and a slower mid-game: about 6–8 years to the Renaissance on Normal, with distinct beats (see the `visible-distribution-direction` note on the issue).

`tier-needs-data` already lets a pack add a need with `neededBy` on a good, and a need without its own rate is eaten at 1 per 8 residents. This change is therefore data only in CityCore; the rest is the PlayerBot, the art wiring and the sweeps.

## Goals / Non-Goals

**Goals:**
- A producer → producer chain whose end product is a new merchant need.
- The Renaissance on Normal stays at 6–8 years for the scripted town; merchants and bankruptcies do not regress against `main`.
- The PlayerBot provisions the chain from demand, so the sweeps measure whether the chain is reachable, not whether a fixed script happens to build it.

**Non-Goals:**
- Per-good storage and the removal of the rest rule (`feat/per-good-storage-main`), and producer → producer carrying (`visible-distribution`). The chain uses the carriers that exist.
- A rival wool chain. Rivals never reach merchants in their build script, so they neither need nor make cloth.
- Cloth as a tier-2 need, and a culture-specific cloth.

## Decisions

### D1. Numbers copy the luxury chain

The sheep farm yields 1 wool per 40 ticks, the weaver turns 2 wool into 1 cloth per 50. These are the hop garden's and the brewery's cycles. A merchant house of 8 eats 1 cloth per 100 ticks, so one weaver (1 cloth per 50 ticks) feeds two full merchant houses and needs 2.5 sheep farms to run flat out. The bot builds 2 sheep farms per weaver, as it builds 2 gardens per brewery.

Costs: the sheep farm costs 70 and 3 wood, a little above the farm (60, 2 wood) because it carries a flock; the weaver costs 130 with 3 wood and 3 planks and upkeep 1, a little above the brewery's 120 for the loom. Wool sells for 3 and cloth for 14, so the weaver's two wool (6) become a good worth more than the sum.

Alternative: 1 wool → 1 cloth. Rejected: it makes the weaver a pass-through with no reason to be a separate building, and one sheep farm would feed one weaver.

### D2. A tech gates the chain, not an age

`weaving` is a medieval tech costing 700 (the cost of cultivation). Merchants need cloth, so a town that has bread and tools must also research Weaving before its houses can become merchants. That adds one research beat to the mid-game without a new age.

Alternative: available from the start. Rejected: a cheap, early chain slows nothing; the point of the pacing work is another step before the Renaissance's 20 merchants.
Alternative: unlocked by `milling`. Rejected: it would not add a decision, and it ties a textile chain to flour.

### D3. Cloth rests on the generic rate

Cloth uses the default need rate of 1 per 8 residents. No Swift is added to `HousePopulation.amount(of:residents:)`.

### D4. The bot builds the chain from demand

The old kit builds a fixed set of every chain per 12 houses once there are 6 houses. For the wool chain the bot instead provisions from demand. A house wants cloth when it is a merchant house, or one of the next two full citizens houses while bread and tools are in the stores (so cloth is all it lacks). The bot researches Weaving when a house wants cloth, then builds one weaver per two such houses and two sheep farms per weaver. It builds at most three weavers and nothing while 20 cloth already wait in the stores, and with the market it sells cloth and wool above 12 units like the other surplus. This measures cloth as an extra the player must notice, which is what a person does.

The first version counted every full citizens house and had no caps. In the pacing sweep it built up to ten weavers for houses that never moved up, and the stores filled with cloth (195 of 240 units in one game) while bread and tools ran short, so merchants fell back and held less often than on `main`. The caps keep the chain at the size the merchants use. The shared store is still the limit, which per-good storage removes.

Alternative: add the wool chain to the fixed per-set list. Rejected: it hides the new need behind the same trigger as everything else, and it overbuilds in towns that never reach merchants.

### D5. Determinism

The change adds goods, buildings and a tech to the generated catalogs. `Good.allCases` order feeds caravans, supply, material cost and the rival market, so the new goods go after `tools` and before the culture goods. That shifts the order of the culture goods, which is intended and regenerates the `DeterminismFixture` baseline once, on macOS and Linux. Nothing else in the tick loop changes: no new random draws, no floating point.

## Risks / Trade-offs

- [Merchants take longer, so towns pay less tax for longer] → The sweeps measure merchants at year 10, the Renaissance year and bankruptcies against `main`; the weaver's cost is tuned in D1 if they regress.
- [The sheep farm's flock art draws ambient sheep, which the graze planner also places at farms] → The grazing planner reads the farm kinds from the catalog; the sheep farm keeps its drawn fold and gets no extra ambient sheep.
- [Existing saves with merchant houses decline until a weaver exists] → Declared BREAKING in the proposal; the tier decline takes 120 ticks per tier, and the Weaving tech costs 700.
- [A second pack format change lands in parallel (`storagePerGood`)] → The new goods and buildings use only fields both formats accept.

## Evidence

Filled in when the sweeps have run: before (main) and after, for pacing, solvency, rivals and the no-market control.
