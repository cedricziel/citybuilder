## Why

`rival-ai-viability` made every rival survive, but its 10-seed sweep has no margin above the year-5 floors of the "Rival viability" requirement. The weakest Normal rival has 20 residents against a floor of 20, and the weakest Hard rival 30 against 30. Any small balance change can turn the weekly `rival-sweep` workflow red (#98).

The weak rivals share one pattern. Each sits at its building cap with food at 0, empty houses and an unspent treasury in the thousands, for three reasons:

- **No warehouse.** The opening's warehouse needs a whole empty block and $200. It is skipped after 10 turns of waiting and never comes back, so 58 of 60 rivals store everything in their 40-unit town center. Planks fill it, and the farms' food has nowhere to go: up to 274 food sits in a Hard rival's farms while its houses starve.
- **Too few farms.** One farm makes 1 food every 40 ticks, slower in winter. A citizens' house of 6 eats 3 food every 100 ticks, so one farm per house cannot feed a full house.
- **Dead huts fill the cap.** Huts whose forest is cut stay standing, and the wood rule keeps adding new ones. A Normal rival ends with 15 huts beside 14 houses.

## What Changes

- **BREAKING (rival AI):** a rival whose town center is full, with no warehouse built or under construction, builds a warehouse before any threshold rule, at the building cap too.
- **BREAKING (rival AI):** the farm rule keeps three farms for every two houses instead of one per house.
- **BREAKING (rival AI):** once a rival has a forester, the wood rule stops at 2 + houses / 2 lumberjack huts, counting thinned huts.

The year-5 floors (8, 20 and 30 residents) stay as they are; this change adds margin above them.

Out of scope: new building kinds for rivals, rival demolition, and the caps themselves.

## Capabilities

### New Capabilities
- (none)

### Modified Capabilities
- `rival-towns`: "Rival build order" gains the warehouse step, the new farm ratio and the hut limit.

## Impact

- **CityCore**: `Systems/RivalSystem.swift` only.
- **Determinism**: archipelago games with rivals play out differently, so the `DeterminismFixture` output and the `game-data-codegen` baseline change on purpose.
- **Tests**: two rival test fixtures whose stock filled the town center exactly now leave room, so the warehouse step stays out of them.
