## Why

A history event fires at the turn of a year and applies at once (`calendar-and-events`). The player can't see it coming, can't prepare and can't answer it. Rats in the granary is the only bad one, and difficulty only changes how often it comes. Issue #257 (roadmap item 3 of the campaign design, #237) asks for events that are announced a season ahead, that the player can prepare for, and that have a building as the answer. Hard Ground 4, "Fire and Fever", can't ship without them (`add-campaigns` D9), and The Long Chronicle 2 wants a blight for an optional bonus goal.

Design canvas: https://claude.ai/artifact/NfTHPHsBMu4gKzjgvxYfz5 (fire, ruins, fire watch, granary, physician, warning banner, festival notice; awaiting approval).

## What Changes

- **Seasonal events, a new system next to the history events.** At most one a year, from the third year on. Four of them, each with its counterplay:

  | Event | What happens | Counterplay |
  |---|---|---|
  | **Fire** | A house or workshop catches fire. After 150 ticks it spreads to every flammable building whose footprint touches it. After 300 ticks it burns down to ruins, which block the plot until cleared for a fee. | A **fire watch** (cheap 1×1 tower, 8 tiles, on the roads) sends a watchman who puts the fire out before it spreads. A road between two buildings is a firebreak. |
  | **Blight** | Crop fields within 6 tiles of a marked field yield nothing for one season; residents who leave hungry are its toll. | The **town market** sells 150 more food a season from the warning to the end. A **granary**: a food-only store that is drawn from last and that rats leave alone, so it holds a reserve. Fields spread over the island help too. |
  | **Fever** | Houses in a marked district can't advance a tier for one season, and lose a resident every 200 ticks. | A **physician** that burns **herbs** covers 8 tiles: houses in reach are spared. Herbs come from a new **herb garden**, a one-step chain, or from the market. |
  | **Festival** | The town asks for bread and its culture's luxury within a season. | Deliver both, and houses in reach of a marketplace advance in half the time and pay 10% more tax for a year. |

- **Warning first.** Fire, blight and fever are announced at the start of the season before they strike, with a parchment banner and an event chip next to the date that stays until the event is over. Blight and fever mark their area on the map from the warning on. Banner text is fixed in the spec.
- **Game data.** A new `Event` item kind in an `events` pack holds each event's seasons, earliest age, weights and banner text. Chapters can schedule events by year and season, and turn the random draw off.
- **Optional.** New Game offers "Seasonal events: On/Off", default On. Chapters that schedule events ignore it.
- **Seeded.** The year's event, its season and its targets come from the world seed and the year alone; the world's random sequence is never drawn from.
- **Difficulty** sets the chance, the weights, the first year, how fast fire spreads, how many fires start, how fast fever empties houses and the festival's reward.
- **History events stay as they are.** Rats in the granary now skips granaries.
- **New buildings:** fire watch, granary, physician and herb garden; ruins as a building that isn't in the palette. **New good:** herbs.
- **New goals** for chapters: "no building lost to fire" and "no house drops a tier during a blight".
- **Seen on the map and in the HUD:** flames and smoke on a burning building, the watchman walking with a bucket, ruins, the marked area of a warned blight or fever, new status icons, an event chip, the festival request on the order board and a festival crowd on the plaza (#127).
- **Statistics** record each season's event and its toll: fires, buildings lost, residents who left, the festival.

## Capabilities

### New Capabilities
- `seasonal-events`: the catalog, the schedule, warnings, fire, blight, fever, the festival, chapter scheduling and determinism.

### Modified Capabilities
- `calendar-and-events`: rats in the granary skips granaries.
- `buildings-and-construction`: fire watch, granary, physician, herb garden, ruins and clearing them.
- `goods-and-production`: herbs; granaries are drawn from last; blight slows crops.
- `population-and-needs`: fever, festival advancement, and how both interact with the decline grace (#274).
- `difficulty-and-goals`: difficulty shapes seasonal events; event goals.
- `orders`: the town is an issuer, for festivals only (`add-orders`, #277).
- `statistics`: seasons record events (`add-statistics-screen`).
- `platform-shells`: warning banners, the event chip, outcome banners, the ruins inspector.
- `rendering-2_5d`: fire, smoke, ruins, the watchman, marked areas, event status icons, the festival crowd.
- `persistence-save-load`: saves before events load with none.
- `world-events`: the new event cases.

## Impact

- **Order of work:** after per-good storage (merged) and #238 M2 (market porters and the marketplace). The catalog, schedule, warnings and fire can start earlier (tasks.md, sections 1–4). Blight, fever and the festival touch house supply and the marketplace, so they wait for M2. The festival also waits for orders (#277).
- **Game data:** new `events.yaml` pack and `Event` kind in `GameDataGen`; `crop` flag on buildings; `events` and `randomEvents` on chapters (`add-campaigns`); the herbs good; four buildings and ruins.
- **CityCore:** new `SeasonalEvents.swift` and `Systems/SeasonalEventSystem.swift`; changes in `Calendar.swift` (rats), the store draw order (granary last), `World+Population.swift` (fever, festival), `Production.swift` (blight), `World+BuildingIssues.swift`, `Difficulty.swift`, `Goals.swift`, `WorldEvent.swift`, `WorldSnapshot.swift`.
- **CityUI / CityRender2D:** banners, event chip, ruins inspector, overlays, status icons, fire and ruin sprites, watchman. All art waits for the canvas approval.
- **Saves:** additive keys, no version bump. `DeterminismFixture` moves once, in its own commit.
- **Sweeps:** a PlayerBot `EventsKit`. The guided Hard first hour has to stay solvent with events on, and the pacing, solvency and rival bars have to hold (design D12).
- **design/web:** the new buildings, ruins, fire effect, status icons, event chip and festival card get components when the art lands. This change adds none.
