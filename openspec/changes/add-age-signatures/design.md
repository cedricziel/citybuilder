## Context

See proposal.md (Why). Relevant facts about the model at the base commit:

- `World.tick()` drains commands, then runs `advanceBuildings`, production, carriers, ships, population, research, calendar, goals and economy, in that order.
- Production advances `ProductionProgress.ticksThisCycle` by 1 per tick (crops skip every other tick in winter) and completes a cycle at `ticksThisCycle >= recipe.cycleTicks`.
- Supply carriers fetch a producer's recipe inputs from goods buffers on its road network until stock plus in-flight reaches twice the recipe amount.
- `HousePopulation.capacity` is `tier.capacity`; growth happens every 60 ticks while needs are met, tier changes after 120 ticks.
- Era techs (`feudalOrder`, `printingPress`, `steamPower`, `electricity`) unlock no buildings today. A game started in an age has every earlier era tech researched.
- `Building` has a tolerant custom decoder; `World` uses synthesised `Codable`, so a new `World` field would need a migration. Saves are at version 8; `add-rival-towns` plans version 9.

## Decisions

### D1 — Signatures stay from their age on

A signature becomes available when the city reaches its age and keeps working for the rest of the game. A Modern city can use all five.

- **Alternative — active only during its age.** Rejected: ages only go forward, so a monument the player spent an age building would switch off at the next era tech, which punishes advancing. It would also contradict the obsolete-buildings rule, under which placed buildings keep working.
- **Alternative — made obsolete by the next age (no new placements).** Rejected: the effects don't overlap (tax, workshop speed, growth, fuel), so there is nothing to replace.

Unlocking uses the existing tech lock: Feudal Order unlocks the guild hall, Printing Press the gallery, Steam Power the steam engine and Electricity the power plant. The monument has no tech, so it is available in every age. A game started in the Renaissance therefore has the monument, guild hall and gallery from the first tick.

### D2 — Catalog entries

| Kind (raw value) | Footprint | Cost | Materials | Upkeep | Build ticks |
|---|---|---|---|---|---|
| monument (`monument`) | 3×3 | $300 | 6 wood, 6 planks | 0 | 60 |
| guild hall (`guild-hall`) | 3×3 | $250 | 4 wood, 6 planks | 3 | 40 |
| gallery (`gallery`) | 2×2 | $180 | 2 wood, 4 planks | 2 | 35 |
| steam engine (`steam-engine`) | 2×2 | $220 | 2 wood, 4 planks, 2 iron | 3 | 40 |
| power plant (`power-plant`) | 3×3 | $400 | 6 planks, 4 iron | 6 | 60 |

All five are land-only. The monument, steam engine and power plant get a 16-unit stockpile; the guild hall and gallery get none.

### D3 — Ranges

`World.footprintDistance(_ a: Building, _ b: Building) -> Int` is the Chebyshev gap between the two footprints: `max(0, b.minX − a.maxX, a.minX − b.maxX, b.minY − a.maxY, a.minY − b.maxY)`. Touching footprints have distance 1; a building is **within r tiles** of a source when the distance is at most r. Ranges ignore roads and water.

Effects reach only operational buildings of the same owner as the source. Until `add-rival-towns` lands, every building is the player's; once it lands, island ownership keeps effects from crossing to a rival.

- **Alternative — reach along the road network.** Rejected: harder for the player to read than a ring, and costlier to compute every tick.

### D4 — Workshops and speed bonuses

`BuildingKind.isWorkshop` is true when the kind's recipe has at least one input and at least one output. That covers the sawmill, bakery, windmill, quern house, charcoal burner, smelter, toolsmith and the four culture producers; it leaves out raw producers (farm, grain farm, lumberjack hut, mine, gardens), the shipyard and the monument.

Each tick, before advancing a workshop, production adds a bonus to its progress:

| Source | Condition | Extra progress |
|---|---|---|
| guild hall | workshop within 8 tiles of an operational guild hall | +1 on ticks where `tickCount % 4 == 0` (+25%) |
| steam engine | within 6 tiles of a fuelled steam engine | +1 every tick (+100%) |
| power plant | within 10 tiles of a fuelled power plant | +1 on ticks where `tickCount` is even (+50%) |

Sources of different kinds add up; several sources of the same kind count once. Bonuses only apply on ticks where the workshop actually advances (not stalled). A cycle still completes at `ticksThisCycle >= cycleTicks` and resets to 0, so surplus progress is dropped. A sawmill (25 ticks) next to a guild hall finishes in 20 ticks; next to a fuelled steam engine in 13.

- **Alternative — multiply output per cycle.** Rejected: workshops would need double inputs per cycle, and stockpiles of 16 would fill twice as fast; faster cycles keep the recipe intact.

### D5 — Fuel

`FuelSpec(good: Good, amount: Int, intervalTicks: UInt64)` on `BuildingKind.fuel`:

| Kind | Fuel |
|---|---|
| steam engine | 1 charcoal every 50 ticks |
| power plant | 2 charcoal every 50 ticks |

Supply carriers treat fuel like a recipe input: they keep stock plus in-flight at 2 × `amount`. A new `runSignatureSystem` runs after `advanceBuildings` and before production. On ticks where `tickCount % intervalTicks == 0` it visits operational fuelled kinds in ID order: if the stockpile holds `amount` it withdraws it and sets `Building.fuelled = true`; otherwise it withdraws nothing, sets `fuelled = false` and, on the true → false edge, emits `fuelRanOut(building:kind:)`. A new building starts unfuelled. Production in the same tick sees the updated flags.

`add-culture-signatures` reuses `FuelSpec` for the culture luxuries.

- **Alternative — make fuel a recipe input.** Rejected: a recipe without outputs stalls and emits `productionStalled` whenever fuel is missing, which reads as broken, and a stall can't express "burn every N ticks".
- **Alternative — add coal and a coal mine.** Deferred: charcoal already exists and competes with smelters, which is the trade-off the steam age needs.

### D6 — Monument project

One monument per owner: `canPlace` rejects a second (constructing or operational) with `.alreadyBuilt(.monument)`, checked after the tech check. A demolished monument can be rebuilt from stage 0.

Once operational the monument works on a project. `ProductionCatalog` gives it the recipe inputs 2 wood, 2 planks, 1 bread, no outputs, 60 ticks. Each completed cycle adds 1 to `Building.projectStages`. At 25 stages it emits `monumentCompleted(building:)`, and from then on production and supply skip it. The full project takes 50 wood, 50 planks and 25 bread and at least 1,500 ticks. While unfinished, a monument stalls like any producer when inputs are missing.

A completed monument raises the owner's tax: each tax interval the summed house tax is multiplied by 110 and divided by 100 (rounded down). A city with $32 tax per interval gets $35.

- **Alternative — a city-wide happiness bonus.** Rejected: there is no happiness value in the model; tax is visible and testable.
- **Alternative — several wonders to choose from.** Deferred: one project proves the mechanic.

### D7 — Gallery commissions

`Command.commission(EntityID)` on an operational gallery with no running commission and a balance of at least $200 deducts $200, sets `Building.commissionTicksLeft = 1200` and emits `commissionStarted(building:)`. Otherwise it is ignored. `runSignatureSystem` decrements every running commission by 1 per tick; reaching 0 emits `commissionEnded(building:)`.

Houses within 8 tiles of a gallery with a running commission are **inspired**: when their needs are met they grow every 30 ticks instead of 60, and they advance a tier after 60 ticks instead of 120. Decline is unchanged. Several galleries count once.

- **Alternative — commissions that grant knowledge.** Rejected: libraries already turn money into knowledge; growth near a gallery makes the gallery's position matter.

### D8 — Capacity modifiers

`World.houseCapacity(of: EntityID) -> UInt32` is `tier.capacity − 2 (smoky) + 2 (energised)`, at least 1:

- **Smoky:** within 4 tiles of a fuelled steam engine.
- **Energised:** within 10 tiles of a fuelled power plant.

The population system uses this capacity for growth, for "full" in the tier-advance rule and for the decline clamp. A house above its capacity loses 1 resident every 60 ticks, even with its needs met. Power plants make no smoke.

A smoky peasant house has capacity 2 and so counts as full at 2 residents. Accepted: it still pays tax on 2 residents instead of 4.

- **Alternative — smoke lowers tax.** Rejected: capacity shows on the map and in the inspector, and drives everything else (tax, knowledge, goals).

### D9 — Rendering

- **Range rings:** while placing a signature kind, and while one is selected (the scene reads the inspected tile through a `selectionProvider`, passed through `SnapshotRendererRegistry`), the scene outlines the tiles within its range (8 / 6 and 4 / 10 / 8 for the guild hall / steam engine smoke and speed / power plant / gallery) as a translucent diamond outline drawn in code, and highlights buildings it would affect.
- **Monument stages:** an operational, unfinished monument shows `building-monument-constructing-0` for stages 0–8, `-1` for 9–16 and `-2` for 17–24; a finished one shows its operational animation.
- **Animation by state:** steam engines and power plants play their operational frames only while fuelled, and galleries only while a commission runs; otherwise they show the idle sprite. Guild halls animate whenever operational.
- **Smoke tint:** smoky houses get a grey blend (`#808080`, blend factor 0.25).

### D10 — UI

- **Inspector:** monument "Stage 12 of 25" or "Complete: taxes +10%"; guild hall "Speeds up 4 workshops"; gallery button "Commission art ($200)" (disabled while running or when the balance is short) and "Commission ends in 1:04"; steam engine "Fuelled" or "Out of charcoal", "Speeds up 3 workshops · smokes 2 houses"; power plant "Fuelled" or "Out of charcoal", "Energises 9 houses, 4 workshops". Counts come from `World.signatureCoverage(of:among:)`, which counts `World.signatureTargets(of:among:)`, the same targets the range-ring highlight uses.
- **House notes:** "Smoky: −2 residents", "Energised: +2 residents", "Inspired by patronage".
- **Banners:** `monumentCompleted` "The monument is complete", `fuelRanOut` "<Kind> is out of charcoal", `commissionEnded` "The gallery's commission has ended".

### D11 — Art

Five buildings in `buildings.py`, base style with age materials, each with an idle sprite, three construction stages and two operational frames:

- **Monument (3×3):** stepped stone podium, temple front with six columns and a pediment, bronze brazier on the steps. Construction stages: podium, columns in scaffolding, roofless colonnade. Operational frames: brazier flame.
- **Guild hall (3×3):** stone ground floor, two timber-framed storeys, steep tiled roof with a bell turret, hanging guild sign. Frames: sign swinging.
- **Gallery (2×2):** stuccoed palazzo front with an arched loggia, cornice and statue niche, banner on a pole. Frames: banner flutter.
- **Steam engine (2×2):** brick engine house, tall round chimney, rocking beam, coal heap. Frames: beam up with a smoke puff, beam down.
- **Power plant (3×3):** brick and concrete hall with tall windows, two chimneys, transformer yard with a pylon. Frames: window glow and light chimney haze.

### D12 — Saves

No migration. `Building` gains `projectStages: UInt8`, `fuelled: Bool` and `commissionTicksLeft: UInt32`, read as 0 / false / 0 when missing. `Command` gains `commission(EntityID)`, which old saves don't contain. The new kinds only appear in new saves. The save version stays at 8, or 9 once `add-rival-towns` lands.

## Risks / Trade-offs

- **[Risk] Speed bonuses starve workshops of inputs.** A doubled sawmill needs twice the wood. → Accepted: that is the steam age's decision; the inspector shows stalls.
- **[Risk] Charcoal demand from engines and plants starves smelters.** → Accepted as the intended trade-off; coal is listed as deferred.
- **[Risk] Range checks cost time every tick.** → Mitigation: production and population each build the list of active sources (`World.activeSignatureSources()`, at most a few dozen) once per tick, and each workshop or house checks only that list. A tick budget test runs a world with 10 guild halls, 10 steam engines and 3 power plants and keeps the mean tick under 100 ms.
- **[Trade-off] Modern cities stack all five signatures.** Accepted: the numbers are small and each source needs upkeep, fuel or money.
