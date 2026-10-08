## Why

Since `add-historical-ages` the five ages look different and swap old buildings for new ones, but they play the same: an Industrial town is a Medieval town with brick houses. The game direction asks for one signature mechanic per age, so that reaching a new age gives the player a new kind of decision, not only new sprites.

## What Changes

- **One signature building per age**, unlocked when the city reaches that age and kept for the rest of the game:

  | Age | Building | Unlocked by | Mechanic |
  |---|---|---|---|
  | Antiquity | monument | always available | a 25-stage project fed with wood, planks and bread; once finished, all tax income +10% |
  | Medieval | guild hall | Feudal Order | workshops within 8 tiles work 25% faster |
  | Renaissance | gallery | Printing Press | pay $200 to commission art; for 1,200 ticks houses within 8 tiles grow twice as fast and advance a tier in half the time |
  | Industrial | steam engine | Steam Power | burns 1 charcoal every 50 ticks; while fuelled, workshops within 6 tiles work twice as fast and houses within 4 tiles lose 2 capacity to smoke |
  | Modern | power plant | Electricity | burns 2 charcoal every 50 ticks; while fuelled, houses within 10 tiles gain 2 capacity and workshops within 10 tiles work 50% faster |

- **Workshops:** a building whose recipe has both inputs and outputs (sawmill, bakery, windmill, quern house, charcoal burner, smelter, toolsmith, and the culture producers from `add-culture-content`). Speed bonuses from different sources add up; two sources of the same kind don't.
- **Fuel:** steam engines and power plants keep a small fuel stock that supply carriers fill, like producer inputs. They burn fuel on a fixed interval and only work while the last burn succeeded. The same fuel mechanism is reused by `add-culture-signatures`.
- **Capacity modifiers:** a house's capacity is its tier's capacity −2 when smoky and +2 when energised (never below 1). A house above its capacity loses one resident every 60 ticks.
- **Monument:** one per city. The finished building shows its build-up through the construction sprites until the project is complete.
- **Gallery commissions:** a new command; the inspector shows a "Commission art ($200)" button and the time left.
- **UI:** range rings when placing or selecting a signature building, inspector lines for each mechanic, and house inspector notes (smoky, energised, inspired).
- **Art:** five buildings in the procedural sprite kit, in the base style with age-appropriate materials.
- **Saves:** no migration. The new per-building fields (`projectStages`, `fuelled`, `commissionTicksLeft`) decode as 0/false when missing, and the new command case only appears in new saves.

Deferred: coal as a separate good and a coal mine, power lines and grid connectivity, culture variants of the age buildings, goals and scenarios built on signatures, auto-renewing commissions, rival towns building signatures, signature-themed history events.

## Capabilities

### New Capabilities

- `age-signatures`: the five signature buildings, their rules, workshops, fuel, capacity modifiers and commissions.

### Modified Capabilities

- `research`: era techs unlock the signature buildings.
- `buildings-and-construction`: five catalog entries and the one-monument rule.
- `goods-and-production`: workshop speed bonuses.
- `population-and-needs`: capacity modifiers and faster growth under patronage.
- `economy`: the monument tax bonus.
- `rendering-2_5d`: range rings, monument progress sprites, fuel-driven animation, smoke tint.
- `platform-shells`: inspector lines, commission button, house notes.
- `sprite-style-catalog`: five buildings.

## Impact

- **CityCore:** five `BuildingKind`s and specs, `Tech.unlocks` for the four era techs, `BuildingKind.fuel: FuelSpec?`, `BuildingKind.isWorkshop`, `Building.projectStages`, `Building.fuelled`, `Building.commissionTicksLeft` with tolerant decoding, `World.footprintDistance`, `runSignatureSystem`, production speed bonus, `World.houseCapacity(of:)`, monument tax bonus, `PlacementRejection.alreadyBuilt`, `Command.commission`, `WorldEvent.monumentCompleted`, `.commissionStarted`, `.commissionEnded`, `.fuelRanOut`.
- **CityRender2D:** range ring overlay, monument stage mapping, idle versus animated by fuel or commission, smoky tint.
- **CityUI:** inspector sections, commission button, house notes.
- **Art:** five buildings in `buildings.py` and five catalog entries.
- **CityPersistence:** none.
