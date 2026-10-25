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

Costs copy the luxury chain too: the sheep farm costs 60 and 2 wood like a hop garden, the weaver 120 with 3 wood, 3 planks and upkeep 1 like a brewery. Wool sells for 3 and cloth for 14, so the weaver's two wool (6) become a good worth more than the sum. The first version cost 70 and 130; the pacing sweep put a few marginal towns into bankruptcy, and the luxury chain's prices are the ones the economy is already tuned around.

Alternative: 1 wool → 1 cloth. Rejected: it makes the weaver a pass-through with no reason to be a separate building, and one sheep farm would feed one weaver.

### D2. A tech gates the chain, not an age

`weaving` is a medieval tech costing 720, the price of Milling and Mining (Cultivation costs 900, Metallurgy 1,440). Merchants need cloth, so a town that has bread and tools must also research Weaving before its houses can become merchants. That adds one research beat to the mid-game without a new age.

Alternative: available from the start. Rejected: a cheap, early chain slows nothing; the point of the pacing work is another step before the Renaissance's 20 merchants.
Alternative: unlocked by `milling`. Rejected: it would not add a decision, and it ties a textile chain to flour.

### D3. Cloth rests on the generic rate

Cloth uses the default need rate of 1 per 8 residents. No Swift is added to `HousePopulation.amount(of:residents:)`.

### D4. The bot builds the chain from demand

The old kit builds a fixed set of every chain per 12 houses once there are 6 houses. For the wool chain the bot instead provisions from demand. A house wants cloth when it is a merchant house, or one of the next two inhabited citizens houses while bread and tools are in the stores (so the cloth is ready when they fill up). The bot researches Weaving when a house wants cloth, then builds one weaver per two such houses and two sheep farms per weaver. It builds at most three weavers and nothing while 20 cloth already wait in the stores, and with the market it sells cloth and wool above 12 units like the other surplus. This measures cloth as an extra the player must notice, which is what a person does.

The first version counted every full citizens house and had no caps. Counting the next two inhabited citizens houses instead of full ones starts the chain a little earlier, so towns reach their first merchants about as soon as without cloth. In the pacing sweep it built up to ten weavers for houses that never moved up, and the stores filled with cloth (195 of 240 units in one game) while bread and tools ran short, so merchants fell back and held less often than on `main`. The caps keep the chain at the size the merchants use. The shared store is still the limit, which per-good storage removes.

Alternative: add the wool chain to the fixed per-set list. Rejected: it hides the new need behind the same trigger as everything else, and it overbuilds in towns that never reach merchants.

### D5. Determinism

The change adds goods, buildings and a tech to the generated catalogs. `Good.allCases` order feeds caravans, supply, material cost and the rival market, so the new goods go after `tools` and before the culture goods. That shifts the order of the culture goods, which is intended and regenerates the `DeterminismFixture` baseline once, on macOS and Linux. Nothing else in the tick loop changes: no new random draws, no floating point.

## Risks / Trade-offs

- [Merchants take longer, so towns pay less tax for longer] → The sweeps measure merchants at year 10, the Renaissance year and bankruptcies against `main`; the weaver's cost is tuned in D1 if they regress.
- [The sheep farm's flock art draws ambient sheep, which the graze planner also places at farms] → The grazing planner reads the farm kinds from the catalog; the sheep farm keeps its drawn fold and gets no extra ambient sheep.
- [Existing saves with merchant houses decline until a weaver exists] → Declared BREAKING in the proposal; the tier decline takes 120 ticks per tier, and the Weaving tech costs 720.
- [A second pack format change lands in parallel (`storagePerGood`)] → The new goods and buildings use only fields both formats accept.

## Evidence

Mid-game pacing (the `rival-sweep` workflow's `midGamePacingAcrossSeeds`, `RIVAL_SWEEP=1 PACING_RETENTION=1`, release build): seeds 0–9 at every difficulty on both layouts with the market, so 20 games per row, each run to year 10. Medians (retention is a mean) on `main` at edb4732d, which has per-good storage, → this change merged with it:

| Difficulty | Bot order | First merchant (yr) | Renaissance (yr) | No merchant by year 10 | Bankruptcies | Share of turns in years 8–10 with 20+ merchants |
|---|---|---|---|---|---|---|
| easy | careful | 4.0 → 4.1 | 5.3 → 5.5 | 2 → 2 | 0 → 0 | 0.79 → 0.82 |
| easy | naive | 4.2 → 4.2 | 5.2 → 5.4 | 2 → 2 | 0 → 0 | 0.85 → 0.85 |
| easy | naiveFollowingHints | 3.9 → 3.9 | 5.2 → 5.4 | 1 → 1 | 0 → 0 | 0.84 → 0.86 |
| normal | careful | 4.6 → 4.9 | 6.6 → 6.5 | 1 → 1 | 0 → 0 | 0.75 → 0.76 |
| normal | naive | 4.8 → 4.8 | 6.2 → 7.1 | 2 → 2 | 0 → 0 | 0.82 → 0.84 |
| normal | naiveFollowingHints | 4.5 → 4.6 | 6.3 → 6.3 | 2 → 2 | 0 → 0 | 0.88 → 0.87 |
| hard | careful | 6.0 → 6.1 | 7.5 → 7.9 | 0 → 0 | 0 → 0 | 0.96 → 0.95 |
| hard | naive | 6.0 → 6.1 | 7.5 → 7.7 | 0 → 0 | 0 → 0 | 0.94 → 0.95 |
| hard | naiveFollowingHints | 6.0 → 6.2 | 7.5 → 7.8 | 0 → 0 | 0 → 0 | 0.98 → 0.98 |

Attainment and solvency hold: bankruptcies stay at 0 in all 180 games, the games without a merchant stay at 10, and the share of turns in years 8–10 with 20 or more merchants is within 0.03 in every row. The Renaissance on Normal careful, the scripted town the pacing target refers to, stays at 6.5 years (6.6 on `main`), inside the 6–8 year goal; cloth did not make it slower there. The naive order on Normal is 0.9 years later (6.2 → 7.1). The other orders and difficulties move by 0.0–0.4 years. The merchants at the end of year 10 are a snapshot that depends on when the town's tools run out: in Normal careful, six games sit at 0 at that tick against one on `main`, while their retention over years 8–10 is 0.88–0.98.

Other sweeps, `main` against this change, identical: the solvency sweep (no bankruptcy in 20 games; control without the market 4 of 30 bankrupt, with it 0 of 30), the guided Hard start (every game's residents the same) and the rival viability sweep (60 rival lines, every year-3, year-5 and year-15 figure the same). The bot builds nothing of the wool chain in those, and rivals never reach merchants.

Before per-good storage landed, the shared store made cloth crowd out bread and tools, and the same chain cost more: the first bot, with no caps, built up to ten weavers and filled the stores with cloth (195 of 240 units in one game), and merchants held less often than on `main`. The bot's limits (at most three weavers, nothing while 20 cloth wait, selling surplus cloth and wool, starting the chain for the next two inhabited citizens houses) and the luxury-chain prices (sheep farm 60, weaver 120, Weaving at Milling's price) came out of those sweeps. A balance guard before building the chain was tried and dropped: towns never reached their first merchant.
