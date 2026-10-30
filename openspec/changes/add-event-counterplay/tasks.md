## 0. Design

- [x] 0.1 Proposal, design and spec deltas; `openspec validate add-event-counterplay --strict`
- [x] 0.2 Claude Design canvas approved for fire, ruins, fire watch, granary, physician, warning banner and festival notice (https://claude.ai/artifact/NfTHPHsBMu4gKzjgvxYfz5); the owner's answers to the open questions in design.md. Approved 2026-10-29 with the recommended options; events ship in two steps (design D14)

Sections 1–4 can start before #238 M2: they don't touch house supply or the marketplace. Sections 5–6 wait for M2, and section 6 also waits for orders (#277). The art in section 8 waits for 0.2.

## 1. Game data (can start before M2)

- [x] 1.1 Tests first: the `Event` kind (effect, seasons, minAge, weights, banner text), its validation (unknown effect or age, no seasons, spring hazard), the `crop` flag, `events` and `randomEvents` on chapters (done with `add-campaigns` M2: the Chapter kind validates them, rejects a disabled event, and chapter setup fills `SeasonalEventsState.schedule` and `randomEvents`)
- [x] 1.2 `GameDataGen`: model, loader, validator, emitter, JSON schema, `FORMAT.md`; regenerate with `make gamedata`
- [ ] 1.3 The `events` pack with the four events and their banner text; `crop: true` on the farm, the grain farm and each culture's crop; the herbs good; the fire watch, granary, physician, herb garden and ruins items (done: the pack, the crop flags, the granary, the fire watch and ruins; herbs, physician and herb garden with section 5)

## 2. CityCore: schedule and warnings (can start before M2)

- [x] 2.1 Tests first: the `seasonal-events` scenarios for the decision, the first year, the minAge, the target checks, warning → onset → end, chapter scheduling, and the RNG left alone; confirm they fail
- [x] 2.2 `SeasonalEventsState`, `seasonalEvent(forYear:)`, the derived generators and their salts, `Difficulty` knobs (D10), `runSeasonalEventSystem` after the calendar and before orders
- [x] 2.3 The `WorldEvent` cases; the events `enabled` flag; events stay off while the calendar is inactive
- [x] 2.4 CityUI: the New Game "Seasonal events" toggle, default On, passed to `newGame(..., seasonalEvents:)` (hidden for chapters with a schedule; old saves and a `newGame` without it stay off); warning, onset and end banners, the event chip (iOS, macOS, tvOS) and its layout rules (the chip is option B of the approved canvas; chapters never pass through the New Game dialog: `World.newGame(chapter:)` from `add-campaigns` M2 turns events on and sets the chapter's `events` and `randomEvents`, whatever the toggle says)

## 3. CityCore: fire, fire watch and ruins (can start before M2)

- [x] 3.1 Tests first: ignition, spread to touching footprints, roads as firebreaks, burn-down to ruins (stock, residents, carriers), the watchman's response, the queue, Hard's second fire
- [x] 3.2 Fire state, the burning stop (production, tax, growth, deliveries), spread, burn-down and the `ruins` kind with `ruinOf`
- [x] 3.3 The fire watch: coverage, nearest idle watch, the watchman's walk on the road path, dousing; the watchman in the snapshot as a walker. Follow-up: a building touching two road networks paths from one adjacent road only (`anyAdjacentRoad`), so a watch on the other network can miss it; pathing should try every adjacent road
- [x] 3.4 Clearing ruins through Demolish with its fee; `notEnoughMoney`; the ruins inspector (done in CityCore: the fee, `demolitionRejected(notEnoughMoney)` and `ruinsCleared`; the inspector reads "Ruins of a house", "Burnt down in Summer 1202" and "Clear ruins — $15"; a burning building's demolish reads "Pull down — $<fee>")

## 4. Rats and the granary's storage (can start before M2)

- [x] 4.1 Tests first: the granary accepts only food goods; rats skip granaries (the modified `calendar-and-events` scenarios)
- [x] 4.2 The granary building and its per-good storage; the rats change

## 5. After #238 M2: blight, the granary reserve and fever

- [ ] 5.1 Tests first: "drawn last" for every draw path, including the porters M2 adds; blight's area and slowed cycles; fever's district, blocked advancement, residents leaving, physician cover; event losses leave the decline grace alone (#274)
- [x] 5.2 Granary drawn last in the shared store-selection code, so every caller gets it (`World.isDrawnLast` / `granariesLast`: supply and hub restock through `nearestBuffer`, market sales, order dispatch, construction materials); the granary is offered in the palette
- [ ] 5.3 Blight in the production cycle (beside the winter rule)
- [ ] 5.4 Herb garden, physician (fuel rules gated on a warned or active fever), fever in `World+Population.swift`

## 6. After #238 M2 and #277: festival

- [ ] 6.1 Tests first: eligibility (marketplace, both goods made), sizing, town orders outside the limits and favour, the four-season reward, missing it costs nothing
- [ ] 6.2 The `town` issuer in `OrdersState`; the linked pair; the festival reward on advancement and tax; the festival card on the order board (look from 0.2)

## 7. Saves, determinism and sweeps

- [ ] 7.1 Decode a save without the new keys; round-trip with a burning house, a watchman on the road, a warned blight and ruins; fixture from the previous version
- [ ] 7.2 Regenerate `DeterminismFixture` in its own commit; macOS and Linux agree; events off is equal to main
- [ ] 7.3 PlayerBot `EventsKit`; the forced-hazard first-hour variant; the before-and-after sweeps of design D12 (code done for fire season: `EventsKit` builds fire watches, `BotEvents` drives drawn and forced events, and `EventsKitTests` holds the `GUIDE_SWEEP events` and `FIRE_SWEEP` runs behind `RIVAL_SWEEP=1`. Step 1 bars 1 and 2 pass with D10 unchanged; the table is in design D12. Bars 3–6 and the blight, fever and festival answers wait for step 2). Tune D10 until the bars hold and write the measured table into design D12
- [ ] 7.4 Seasonal events in the weekly `rival-sweep` workflow and the `GUIDE_SWEEP`, `PACING_SWEEP` and `SOLVENCY_SWEEP` lines

## 8. Art, rendering and statistics (after 0.2)

- [ ] 8.1 Sprites from the approved canvas: fire and smoke effect, ruins per footprint, fire watch, watchman with a bucket, granary, physician, herb garden; status icons (flame, blight, fever, clear-me) (done: everything but the physician and herb garden, which come with step 2; ruins at 1×1, 2×2 and 3×3; `PendingArt` is gone, and the granary waits in `BuildPalette.held` until 5.2 lands)
- [ ] 8.2 CityRender2D: a real walker type for the watchman (today a zero-amount `.deliver` carrier in `snapshot().carriers`); effects, the amber threat and teal serves overlays, status icon mapping, the festival crowd hook (#127) (done: `WorldSnapshot.watchmen` and the bucket walk cycle, flames, glow and smoke on burning buildings, ruins at their footprint, the flame and clear-me icons, a fire watch's reach in teal and the amber style; still to come: blight and fever areas and icons with section 5, the festival crowd with section 6)
- [ ] 8.3 Statistics: event records per season, the axis markers, the fever series
- [ ] 8.4 `design/web`: components for the new buildings, ruins, fire effect, icons, event chip and festival card; previews; `npm run typecheck` and `npm run build`; republish after merge (done: `FireEffect`, the fire watch, granary and ruins previews, the watchman and the event icons; the event chip and festival card come with 2.4 and 6.2)

## 9. Campaign hooks

- [ ] 9.1 Event goals ("no building lost to fire", "no house drops a tier during a blight") in `Goals.swift`
- [ ] 9.2 Hand Hard Ground 4's schedule and Chronicle 2's blight to `add-campaigns` task 5.3 with the first values from design D9
