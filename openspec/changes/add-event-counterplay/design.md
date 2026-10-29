## Context

- **History events** (`calendar-and-events`) are decided at the turn of each year from `seed` and the year, with a `DeterministicRNG` that never touches the world's RNG. They apply at once and show a 60-tick `SessionBanner`. Difficulty sets the chance (50/50/65%) and the weight of rats (0/1/2).
- **Per-good storage** has merged: stores hold each good apart (`storagePerGood`: 40 at the town center, 80 at warehouses and ports), and a producer whose output has nowhere to go stops. Status icons float over buildings with a problem (`add-building-status-icons`).
- **Fuel rules** (`age-signatures`): a building burns N of a good every M ticks; a burn that finds the good marks it fuelled, one that doesn't marks it unfuelled and emits `fuelRanOut`. Supply carriers keep twice the burn on hand. Ranges are Chebyshev gaps between footprints, touching footprints have a gap of 1.
- **Areas of effect** (`add-areas-of-effect`) draw a building's reach while placing and selecting, and plan a teal "serves" style for house and market reach after #238 M2.
- **Orders** (#277, `add-orders`) put timed requests on a board. The player accepts them, and `dispatchOrder` sends all units at once as shipments to a town center. Order size follows the town's recent output from `statistics`.
- **Decline grace** (#274, `decline-grace`, in progress): a house declines only after a need has been short for N consumption intervals in a row; during the grace it shows the need's "short" icon.
- **Statistics** (`add-statistics-screen`) keep a 40-season ring of player aggregates.
- **#238 M2** adds the marketplace building and porters that carry goods from it to houses. Until it lands, houses draw their needs straight from the stores on their road network.
- **Guided Hard start** (`SolvencyTests`, `GUIDE_SWEEP`): 10 seeds × 2 layouts, 12,000 ticks (five years). Every run must be solvent with at least 25 residents.

## Goals / Non-Goals

**Goals:**
- Four events with a warning a season ahead and a building that answers each.
- Events as game data, seeded, and schedulable by chapters.
- Every outcome computed in CityCore, so PlayerBot sweeps can prove the guided first hour survives and the pacing holds.
- Visible on the map: flames, the watchman, ruins, marked areas, a festival crowd.

**Non-Goals:**
- Events for rival towns. They have no counterplay AI, and the rival viability sweep would have to be retuned. Later, with #263.
- Clean water, wells against fever, fire stations in later ages, insurance, disasters without counterplay (earthquakes, floods).
- Changing the four history events, apart from rats skipping granaries.
- Art. The canvas comes first; sprites follow its approval.

## Decisions

### D1. A new system beside the history events, not a rework of them

Seasonal events have their own draw, their own salt and their own tick step (`runSeasonalEventSystem`, after the calendar, before orders). History events keep their spring slot, rules and tests.

*Alternative:* move the four history events into the new catalog. It would touch working tests and every history-event save for no player gain. They can join the pack later as `instant` events.

### D2. One event a year, decided in spring, warned a season ahead

At the start of each year from the first event year (D10), the world decides from `seed` and the year alone:

1. whether an event happens (the difficulty's chance);
2. which one, by the difficulty's weights over the events whose `minAge` the player's age has reached;
3. its onset season, from the event's `seasons` list.

Hazards (fire, blight, fever) strike in summer, autumn or winter, never in spring, so the warning lands at the start of the season before: the spring decision itself for a summer onset, summer for autumn, autumn for winter. The festival is a request, not a hazard. Its request appears at the start of its season (spring or summer) and the request is its notice.

The decision is a pure function, `seasonalEvent(forYear:)`, but its result is stored when it is made: the draw depends on the player's age at the start of the year, so a save made after an age-up must not redraw it (D11). Every hazard ends by the end of winter (a fire at the latest at the end of the season after its onset, when the rains put out what still burns), so a year's event never overlaps the next decision. The festival's reward may run into the next year; it doesn't block that year's event. An event still open at a decision (only a hand-edited save) makes the new year's event skip, never defer, scheduled or not. At the warning, the world checks that the event has targets (D3–D6). Without them, there is no warning and no event that year, so a warning is always followed by its event.

*Alternative:* decide every season. That allows two events in a year and makes "a season ahead" harder to read.

### D3. Game data: the `Event` kind and the `events` pack

```yaml
- kind: Event
  id: fire
  effect: fire              # fire | blight | fever | festival: the mechanic, in Swift
  seasons: [summer, autumn] # possible onset seasons
  minAge: antiquity
  weight: { easy: 1, normal: 1, hard: 2 }
  warning: { title: "Dry {season} ahead", text: "..." }
  onset:   { title: "...", text: "..." }
  end:     { title: "...", text: "..." }
```

Mechanics stay in Swift, like `effect: code` on buildings. The tuning numbers that differ per difficulty are in `Difficulty`, as all other difficulty knobs are (D10). Text fields take `{season}`, `{building}`, `{count}`, `{date}`, `{bread}`, `{luxury}` and `{luxuryGood}` placeholders, filled by CityUI. A `Building` gains an optional `crop: true` (farm, grain farm and each culture's crop: hop garden, vineyard, tea garden, coffee grove). Chapters gain `randomEvents` (default true) and `events: [{ year, season, event }]` (D9).

### D4. Fire

- **Targets.** Ignition picks among operational player houses and producers, sorted by entity ID, with the event's derived RNG. *Flammable* buildings are houses, producers, warehouses, granaries, libraries, fire watches, physicians and herb gardens. Town centers, ports, shipyards, roads, monuments and signature buildings are not flammable. The town needs at least 6 flammable buildings for a fire to be warned.
- **When.** The first fire starts at a derived tick in the first half of the onset season. On Hard a second one starts in the second half.
- **Burning.** A burning building stops: no production, no tax, no growth, no goods in or out (deliveries, building materials, returning shipments). It still pays upkeep. It shows flames and a red flame status icon. Demolishing it as a firebreak is allowed: it costs the ruins-clearing fee of its kind (D5) and leaves nothing.
- **Each building burns at most once per event.** A doused or burnt building can't catch again until the event ends, so two neighbours can't keep re-igniting each other. The candidates are recomputed at each ignition tick; an ignition without a candidate is skipped. The warning needs at least one house or producer among the 6 flammable buildings.
- **Spread.** When a fire has burnt for `spreadTicks` (Easy 200, Normal 150, Hard 100), it ignites every flammable building whose footprint touches its own (gap 1, edges and corners), in entity-ID order. Each new fire has its own timers. A road tile between two buildings makes the gap 2, so **roads are firebreaks**. Spread is deterministic and needs no RNG.
- **Burning down.** After 300 ticks the building becomes **ruins** of the same footprint. Its stock is lost, its residents leave, and carriers bound for it are redirected as for a demolished building.
- **Fire watch.** A 1×1 tower. It covers flammable buildings within 8 tiles (gap) that are road-connected to it. When a covered building ignites, the nearest idle watch (by road path length, then entity ID) sends its watchman. He walks the road path at one tile a tick and douses the fire for 30 ticks. The fire is out at arrival + 30. A watch handles one fire at a time; others queue in order of ignition tick, then entity ID. Within 8 tiles the path is rarely over 20 tiles, so a watch is in time before the spread (150 ticks on Normal), even with two fires in a row. A doused building keeps its stock and resumes. No ruins.
- **Why touching footprints and roads.** The issue asks that "spacing and roads matter". Houses are built side by side along roads, so a block of touching houses is the risk and a road is the natural break. A wider spread radius would burn whole towns, and a narrower one would never spread.

*Alternatives:* a random spread chance per tick (unreadable, and a fire would behave differently on a replay); a fire watch that prevents ignition in its radius (no visible response, and no reason to space the town).

### D5. Ruins and clearing

A burnt building becomes a `ruins` building with `ruinOf` set to its kind. It has the burnt kind's footprint, no upkeep and no function, and it isn't in the palette. The Demolish tool clears it for 25% of the burnt kind's money cost, rounded up to $5, at least $10 (a house $15, a sawmill $30, a warehouse $50). Clearing is instant, like demolition. A clear the treasury can't pay is rejected with `notEnoughMoney`. Ruins count toward "buildings lost to fire" (D9).

*Alternative:* clearing takes a builder and time. It needs a new construction mode for a rare action.

### D6. Blight and the granary

- **Area.** At the warning, the world picks one operational player crop field (by entity ID, with the derived RNG). The area is every tile within 6 of its footprint. The area is marked on the map from the warning to the end of the blight, so the player can prepare.
- **Effect.** During the onset season, crop fields in the area take twice their cycle, like a farm in winter, without being marked stalled. Blight never strikes in winter, so the two never stack. A field built in the area during the blight is blighted too.
- **Granary.** A food store: `storagePerGood: 60`, accepts only food, grain, flour and bread, cost $120, 4 wood and 4 planks, upkeep 1, footprint 2×2, no tech. It fills like any store. **Every draw takes from it last:** houses, porters, producers, construction, the market and order dispatch use the other stores on the network first, and a granary only when they hold none of the good. Rats in the granary skip granaries. So a granary is a reserve that only shrinks in a shortage.
- **Why "drawn last" instead of a separate reserve bucket:** it uses the per-good stores and the existing draw path, needs no new UI to "release" the reserve, and works the same for every shortage, not just blight.

*Alternative:* blight halves the output of each cycle. Producers output whole units, so half a unit would need rounding rules; a slower cycle is what winter already does.

### D7. Fever, the physician and herbs

- **District.** At the warning, the world picks a player house with residents (by entity ID, with the derived RNG). The district is every house within 6 tiles of it. Marked on the map like blight. A fever needs at least 6 houses with residents and the Medieval age.
- **Effect.** During the onset season, houses in the district can't advance a tier, and every `feverLeaveTicks` (Easy 300, Normal 200, Hard 150) each of them with 2 or more residents loses one (never below 1). Over a season that is 2, 3 or 4 residents a house.
- **Physician.** Cost $90, 2 wood and 3 planks, upkeep 1, footprint 2×2, no tech. It burns 1 herbs every 100 ticks through the fuel rules, **but only while a fever is warned or under way**. Outside that, it keeps its stock and its fuelled state doesn't change. A house within 8 tiles of a fuelled physician is spared both effects.
- **Herbs, not soap.** Herbs take one new building, the herb garden (gather, cost $50, 2 wood, 1 herbs every 60 ticks, footprint 2×2, no tech). The market sells them too (buy 10, sell 20 a season). Soap would need tallow and ash. Tallow is a second output of the sheep farm, which would change the wool → cloth chain (#273) that the decline-grace sweeps were just tuned against. Soap also needs Weaving before fever could be answered. Herbs fit Antiquity to Medieval and every culture. Soap is a candidate for clean water in the Renaissance. The herb garden is not a crop, so a blight can't take away the answer to a fever.
- **Why burn only while warned:** the physician has no use in quiet years. If it burned all year, the player would pay twelve herbs a year to insure against an event that comes every few years. Burning from the warning on makes the warning season the time to fill the stock, which is the preparation the issue asks for.

### D8. Festival, through the order board

- **The request** is two linked orders from a new issuer, `town`, issued together at the start of the festival's season: bread, and the culture's luxury. Each asks for half of what the town made of the good over the last four closed seasons, scaled to one season (bread: at least 6, at most 30; luxury: at least 4, at most 20), capped at 75% of what the stores can hold. The rules and the shipments are the orders' (D5, D7 of `add-orders`). The window is one season (two on Easy).
- **Eligible** only when the player owns an operational marketplace (#238 M2) and made both goods in that window. Otherwise there is no festival that year, and no other event replaces it.
- **Town orders** don't count toward the two accepted orders, don't touch favour, cost nothing when missed or declined, and don't count toward the "fulfil N orders" goal. They lapse with the season like any offer.
- **Reward.** When both are fulfilled by the deadline, the festival runs for four seasons. Houses within the reach of an operational marketplace advance after 60 ticks of met needs instead of 120, and pay 10% more tax (15% on Easy), rounded down. A festival crowd fills the plaza for the first season (#127).
- **Why the order board:** it already has accepting, dispatching, deadlines, carriers on the roads and a card. A second request UI would duplicate all of it.

### D9. Chapters schedule events; event goals

- A chapter's `events` list names a year, an onset season and an event. A scheduled event replaces that year's random draw. It skips the chance, the weights, the first-year rule and the minimum counts (it needs only one target), and keeps its warning. `randomEvents: false` turns off the draw in all other years.
- **Goals:**
  - "No building lost to fire": met once every fire the chapter schedules has ended and no building of the player burnt down since the game started.
  - "No house drops a tier during a blight": met when a blight ends and no player house dropped a tier between its warning and its end. Both are goals of the existing goal type, checked on the goal interval.
- **First values** for `add-campaigns` task 5.3 to tune:
  - Hard Ground 4: `randomEvents: false`; fire in summer 1202, fever in autumn 1203, blight in summer 1204, fire in autumn 1205.
  - The Long Chronicle 2: a blight in its third summer, with the blight goal as a bonus.

### D10. Difficulty

| | Easy | Normal | Hard |
|---|---|---|---|
| Chance of an event in a year | 35% | 50% | 65% |
| First year with an event | 4th | 3rd | 3rd |
| Weights fire / blight / fever / festival | 1 / 1 / 1 / 3 | 1 / 1 / 1 / 1 | 2 / 2 / 2 / 1 |
| Fires per fire event | 1 | 1 | 2 |
| Fire spreads after | 200 ticks | 150 ticks | 100 ticks |
| Fever: a resident leaves every | 300 ticks | 200 ticks | 150 ticks |
| Festival window | 2 seasons | 1 season | 1 season |
| Festival tax bonus | 15% | 10% | 10% |

These are the first values. Task 7.3 tunes them against D12. The warning is always one season, on every difficulty: it is the promise the system makes. The year 1200 start makes the third year 1202. The guided Hard sweep covers 1200–1204, so it sees up to three event years.

### D11. Saves

- `World.seasonalEvents: SeasonalEventsState`, an optional key:
  - `enabled`: off unless the New Game toggle sets it (`newGame(..., seasonalEvents: true)`); fixtures and `newGame` without it leave it off;
  - `plan`: this year's stored decision (year, event, onset season, or none);
  - `warned`: the warned event (id, onset tick, area anchor and radius, or nil);
  - `active`: fires (entity, ignition tick, responding watch, arrival tick), the blight (anchor, end tick), the fever (anchor, end tick, next leave tick);
  - `festivalUntil`: a tick;
  - `counters`: buildings lost to fire, fires put out, residents who left with fever.
- `Building.ruinOf`, an optional key.
- Both are additive, with no version bump, like `orders` and `decline-grace`. A save without them loads with events off, nothing warned or active, and zero counters, so it ticks exactly as before. A player who wants events in an old game needs a way to turn them on (a later settings change); until then only new games with the toggle on see them.
- Fixtures keep the calendar inactive, and no seasonal event ever happens there. `newGame` and the v5 migration activate the calendar, but events stay off unless the New Game toggle turns them on.
- The world's RNG is untouched. `DeterminismFixture` builds its world without the toggle, so it does not move; a fixture with events on is a separate addition (task 7.2).

### D12. Sweeps and acceptance

A PlayerBot `EventsKit` (tests only), the "events" kit of `add-campaigns` D10:

- on a fire warning, it builds one fire watch per 8-tile cluster of houses and workshops that no watch covers;
- on a blight warning, it builds a granary when it has none;
- on a fever warning, it builds a physician over the marked district and a herb garden, and buys herbs at the market when the physician holds fewer than 2;
- it accepts a festival when its stores already hold half of each good, and sends it when stocked.

Bars, all on the release build in the weekly `rival-sweep` workflow:

1. **First hour:**
   - The guided Hard start (`GUIDE_SWEEP`, seeds 0–9, both layouts, 12,000 ticks) with events on and the kit stays solvent with at least 25 residents in all 20 runs, the bar it has today.
   - A forced variant runs each hazard once in summer or autumn 1202 (60 runs): 0 bankruptcies and at least 20 residents.
2. **The answer matters.** In the forced fire runs, buildings lost to fire with the kit are at most half of those without it. In the forced fever runs, residents who left are at most half.
3. **Pacing:** the mid-game pacing sweep (`PACING_SWEEP`) keeps the median Renaissance on Normal between 6 and 8 years with events and the kit, and within half a year of events off.
4. **Solvency:** `SOLVENCY_SWEEP` (Normal, 10 seeds, both layouts, 36,000 ticks) has 0 bankruptcies with events and the kit. The market control shows no more bankruptcies than without events.
5. **Rivals:** the rival viability sweep keeps its bars. Rivals have no events.
6. **Coverage:** across the pacing sweep, each of the four events fires at least 5 times, and the kit completes at least one festival.

The measured table goes into this section when task 7.3 runs.

### D13. What players see (canvas)

The canvas https://claude.ai/artifact/NfTHPHsBMu4gKzjgvxYfz5 shows the current state and 2–3 options each for fire, ruins, the fire watch, the granary, the physician, the warning banner and the festival notice, with a recommendation. In short, the recommendations are:

- **Fire:** flames on the roof with a smoke column, short enough not to hide the neighbours.
- **Ruins:** a charred timber frame on a blackened plot.
- **Fire watch:** a timber tower with a bell.
- **Granary:** raised on staddle stones.
- **Physician:** a timber house with herb racks and a mortar sign.
- **Warning:** the parchment `SessionBanner` plus an amber event chip under the date chip.
- **Festival:** a town card on the order board.

The final choice is the owner's. Art and `design/web` components follow the approval.

## Risks / Trade-offs

- **[Risk]** A fire in year 3 bankrupts a Hard start. → Ignition comes a season after the warning, a watch costs $60, and the forced first-hour variant is a gate (D12, bar 1).
- **[Risk]** Fire wipes out a dense town that has no watch. → That is the intended lesson, but it is capped: each fire spreads once, to touching buildings, and 300 ticks gives a player who reacts late time to build a watch. A watch finished during a fire answers the fires already burning in its reach.
- **[Risk]** "Drawn last" changes which store a draw empties, and that could change carrier traffic for towns without granaries. → No: the order only differs when a granary exists. Determinism tests cover a town without one.
- **[Risk]** The festival depends on two unfinished changes (#238 M2, #277). → It is its own task group (6) and ships last. The catalog's weights skip an ineligible festival, so the other three events can ship first.
- **[Risk]** Fever interacts with the decline grace (#274). → Residents who leave with fever are not a shortage and don't touch the short-interval count. A house below capacity can't advance anyway, so fever blocking advancement only matters for full houses.
- **[Trade-off]** Events touch only the player. Rival towns don't burn. That keeps the rival sweep stable, at the cost of realism.

## Decisions on the open questions

Decided by the orchestrator on 2026-10-28. The owner can override any of them on the canvas.

1. **Fire watch footprint: a 1×1 tower.** It is cheap, fits into dense towns, and matches the rendered tower (canvas option A's tower on option C's plot). Its ruins are 1×1 too.
2. **Physician:** burns herbs only while a fever is warned or under way (D7). Herbs matter, without a constant drain.
3. **Events toggle:** New Game offers "Seasonal events: On/Off", default On. Its value is `SeasonalEventsState.enabled`. A campaign chapter that schedules events ignores the toggle and always runs its schedule. Its random draw follows `randomEvents`.
4. **Ruins clearing:** 25% of the burnt building's cost (D5), with no wood back.
5. **Missed festival:** no favour cost and no other penalty (D8). A festival is an opportunity, not an obligation.
