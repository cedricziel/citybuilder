## Context

See proposal.md (Why). Relevant facts about the model at the base commit:

- `World` holds one `economy`, one `research`, one `culture`, one `age` and one `difficulty`. Every system treats every building as the player's.
- `ArchipelagoGenerator` paints five fixed islands on a 300×300 map. Island IDs follow row-major scan order: 1 = north-east (2,805 tiles), 2 = north-west (3,569), 3 = centre (6,269, contains the map center tile 150,150), 4 = south-west (2,453), 5 = south-east (3,609). Names come from `IslandNameTable` and depend on the seed.
- `seedTownCenters()` puts an operational town center with the difficulty's starter stock on every island, so today the player starts with five.
- Logistics is already island-local: carriers walk roads, roads never cross water, placement materials come from `islandStockpile(at:)`, and supply uses `sharesRoadNetwork`.
- Commands queue in `pendingCommands` (persisted) and are applied at the next tick boundary. `applyPlace` emits `placementRejected` on failure, which the UI turns into a rejection banner.
- `goodsBuffers()` is global and feeds goals (`storedQuantity`), history events and supply.
- Saves are at version 8.

## Decisions

### D1 — `Owner` on buildings and ships

`RivalID` is a `UInt8` (1…3). `Owner` is an enum `player` / `rival(RivalID)` encoded as a single string (`"player"`, `"rival-1"`). `Building.owner` and `Ship.owner` default to `.player`; their tolerant decoders read a missing key as `.player`. `applyPlace` stamps the placing owner on the building, and `emitShip(fromShipyard:)` copies the shipyard's owner to the ship.

- **Alternative — an `owners: [EntityID: Owner]` side table.** Rejected: every building lookup would need a second lookup, and demolish would have to keep two maps in sync.
- **Alternative — derive the owner from the island the building stands on.** Rejected: it breaks as soon as ships (which have no island) or future outposts exist, and makes every owner query an island scan.

### D2 — Rival setup at new game

`newGame(layout:seed:culture:age:difficulty:rivals:)` gains `rivals: Bool = true` (the scenario overload passes `true`). Rivals are created only when `layout == .archipelago && rivals`.

- **Home island:** the island containing the map center tile; if none, the largest island (lowest ID on a tie).
- **Rival islands:** the remaining islands sorted by tile count descending, then ID ascending; the first `difficulty.rivalCount` (Easy 1, Normal 2, Hard 3) become rival islands, in that order, as rivals 1, 2, 3. With the fixed archipelago this is south-east, then north-west, then north-east; the south-west island stays the player's.
- **Culture:** `Culture.allCases` without the player's culture, in catalog order; rival *n* takes the *n*-th entry. Three rivals at most means they are always distinct and never the player's.
- **Colour:** rival 1 crimson `#B03A2E`, rival 2 azure `#2E6DB4`, rival 3 emerald `#2E8B57`.
- **Name:** the rival island's `Island.name`.
- **Treasury:** Easy $600, Normal $1,000, Hard $1,400 (rivals get stronger as difficulty rises).
- **Age:** the world's start age.
- **Town center:** the town center `seedTownCenters()` already placed on that island is re-owned to the rival and keeps the difficulty's starter stock.

`RivalTown` stores `id`, `name`, `islandID`, `culture`, `colour`, `age`, `treasury`, `townCenterID` and `ai: RivalAIState`. `World.rivals: [RivalTown]` is kept sorted by `id`.

- **Alternative — random rival cultures and islands from the seed.** Rejected: a fixed order makes tests read like the rules and does not consume the world RNG, so existing seeded behaviour is unchanged.

### D3 — Island ownership and the placement rule

`World.owner(ofIsland:)` returns the rival whose `islandID` matches, otherwise `.player`. `canPlace(_:at:for owner: Owner = .player)` adds one check before the tech check: every land tile of the footprint must lie on an island owned by `owner`; otherwise `canPlace` returns `.rejected(.foreignIsland(Owner))`, naming the island's owner. The payload is an `Owner` rather than a `RivalID` so a rival probing a player island gets a well-formed answer too. (Rivals only search their own island, so in play the rejection is only ever shown to the player, naming a rival.) Water tiles of shore buildings are not checked.

- **Demolish:** `.demolish(at:)` from the player is ignored when the building's owner is a rival. Town centers stay demolishable by their owner, as today.
- **Forests:** `.harvestForest(at:)` is ignored on a rival island.
- **Rival exemptions:** for a rival owner, `canPlace` skips the research lock and the obsolete check (rivals don't research; D5 only uses kinds that are always sensible). Terrain, occupancy, shore and material checks apply unchanged.
- **Silent rival rejections:** a rejected `rivalPlace` emits nothing, so the player never sees a rejection banner for the AI.

Outposts are **out of scope**: with this change every island has an owner from turn one (the player keeps the town centers on non-rival islands, as today), so there is nothing to claim. Claiming, and the AI expanding, need unowned islands and belong to a later change.

- **Alternative — make non-home islands unowned and add an outpost building.** Rejected for this slice: it changes the solo game everyone already plays (losing four town centers), needs a new building with art, and needs the AI to decide when to expand.

### D4 — Rival commands go through the queue

`Command` gains `rivalPlace(RivalID, BuildingKind, at: TileCoordinate)`. `apply` routes it to `applyPlace(kind:anchor:owner:)`, which charges the rival's treasury instead of `economy` and deducts materials from the rival's island exactly as for the player.

`runRivalSystem` runs at the end of `tick()`, after the goal system and before the economy. For each rival whose turn is due (`tickCount % rivalTurnTicks == rivalID − 1`, so rivals take turns on different ticks; checked in ID order) it decides at most one step and **appends** the resulting commands to `pendingCommands`. They are applied at the next tick boundary, before any player command enqueued later between ticks. The decision reads only world state and never touches `rng`.

Since `pendingCommands` is part of the saved world, a save taken between the decision and its application reloads into the same next tick.

- **Alternative — let the AI mutate the world directly inside its system.** Rejected: the direction asks for the same command path as the player, and two placement code paths would drift.
- **Alternative — a generic `indirect case asOwner(Owner, Command)`.** Rejected: only placement is needed now, and a recursive enum makes every `switch` over commands handle nesting.

### D5 — The AI builder

**Kit.** Rivals build only `house`, `road`, `lumberjackHut`, `sawmill`, `farm` and `warehouse`. These supply food and planks, which is everything peasants and citizens need, so rival houses top out at citizens (6 residents each). Bread, tools, ports, shipyards, libraries and culture-only buildings are left out.

**Turn interval** (`Difficulty.rivalTurnTicks`): Easy 80, Normal 50, Hard 30.

**Choosing a step.** On its turn a rival takes the first rule that applies:

1. **Threshold rules**, only once the opening is complete (so a fresh rival with the starter stock doesn't build a farm first), checked in this order against the rival's island stock (goods buffers on its island):
   - food < 4 and farms < 1 + houses / 3 → farm
   - planks < 6 and sawmills < lumberjack huts → sawmill
   - wood < 4 and lumberjack huts < 1 + houses / 4 → lumberjack hut
2. **Build order.** Otherwise the next entry of the script. The opening is played once: lumberjack hut, farm, house, house, sawmill, house, house, farm, house, house, lumberjack hut, warehouse. After that the growth loop repeats: house, house, farm, house, house, lumberjack hut, house, sawmill.

**Caps.** A house step is skipped (the script advances) once the rival has 30 houses; no step is taken once the rival has 50 non-road buildings.

**Affordability.** A step is issued only when the treasury is at least the building's cost + road cost (D6) + $50, and the island stock covers the full material cost, so rival buildings never wait for materials. Otherwise the rival waits and keeps the same step. After 10 turns waiting on a script step, it skips that step. Threshold rules never advance the script.

**State.** `RivalAIState` stores `scriptIndex` (0…11 opening, then 12…19 loop, wrapping to 12) and `waitTurns`.

- **Alternative — utility scoring or a planner.** Rejected: harder to test, harder to tune, and nothing in this slice needs it.
- **Alternative — rivals as an abstract population number with no buildings.** Rejected: rivals would be invisible on the map, which defeats the point of a pretty, lively archipelago.

### D6 — The town plan

Each rival builds on a road grid anchored to its town center. With the town center anchor at `(ax, ay)`, grid lines are the columns `x ≡ ax − 1 (mod 5)` and rows `y ≡ ay − 1 (mod 5)`. Between grid lines lie 4×4 **blocks**; the town center's 3×3 footprint sits in block (0, 0).

- A block has four 2×2 **slots** (its corners), each touching the block's ring road. A 3×3 kind (warehouse) takes a whole empty block.
- **Opening a block** means placing every missing road tile on its 5×5 ring. A block can be opened only when all its missing ring tiles are placeable roads and it shares an edge with an opened block (block (0, 0) is always eligible), so the network stays connected to the town center.
- **Slot search.** Blocks are visited by Chebyshev block distance from (0, 0), then row, then column, up to distance 4. Within a block, slots go top-left, top-right, bottom-left, bottom-right. The first slot where `canPlace(kind, at:, for: rival)` is allowed wins. A lumberjack hut additionally needs a forest tile in its catchment (`firstForestInCatchment` non-nil).
- **Commands.** A step enqueues, in one batch, the missing ring roads of each block it opens (block (0, 0) first while it is unopened, then the chosen block; each ring row-major; a tile already in the batch is not repeated), then the building. Block (0, 0) has no free slot because the town center fills it, so the first building always lands in a neighbouring block. Road cost is $5 per enqueued tile and counts toward affordability.
- If no slot exists, the step counts as waiting.

### D7 — Rival economy and what stays the player's

- **Tax:** each tax interval, each house's tax is credited to its owner's purse: the player's `economy` or the rival's `treasury`. `taxesCollected` reports the player's amount only.
- **Upkeep:** charged to each owner. The difficulty upkeep scaling applies to the player only. `upkeepPaid` reports the player's amount only.
- **No rival bankruptcy:** a rival's treasury may go negative; it then can't afford steps and waits.
- **Player-only figures:** `totalPopulation`, `residents(atLeast:)` (era gates, goals), `storedQuantity(of:)` (goals), history events (bountiful harvest, rats) and research knowledge use only player-owned buildings, through a new `goodsBuffers(of: Owner)` and an owner filter on populations.
- **Logistics:** carriers, supply and placement materials stay unchanged. They are island-local and every island has a single owner, so goods never cross owners. A test asserts this.

### D8 — Rival ages

After its turn a rival checks its residents (all tiers) against the next age's threshold: Medieval 24, Renaissance 60, Industrial 108, Modern 150. On reaching it, `age` advances one step and `WorldEvent.rivalAgeAdvanced(RivalID, Age)` is emitted. Rivals start in the world's start age and never skip an age in one turn. Rival age only changes the rival's look (D10) and the standings.

- **Alternative — per-rival research.** Rejected: a second `ResearchState` per rival, plus libraries in the AI kit, for no visible gain in this slice.

### D9 — Standings, the outgrow goal and Island Rivalry

`World.standings() -> [TownStanding]` returns one row per town: owner, name ("You" for the player), colour (player gold `#D4A017`), population, age and wealth (the player's balance or the rival's treasury). Rows are sorted by population descending, ties by owner (player first, then rival ID).

`Goal.outgrowRivals` is met when the player's population is strictly greater than every rival's. Its progress is (player population, largest rival population + 1). In a world with no rivals it is met once the player has at least one resident.

`Scenario` gains `requiredLayout: WorldLayout?` (nil for the existing three) and a fourth case, **Island Rivalry** (`island-rivalry`): Medieval, Normal, archipelago, goals `.outgrowRivals` and 80 residents. Blurb: "Out-build two rival towns and reach 80 residents."

### D10 — Rendering

`WorldSnapshot` gains `rivals: [RivalSummary]` (id, name, colour, culture, age, island) and `culture(for: Owner)` / `age(for: Owner)`. `CultureSprites` looks up culture and age by the building's owner instead of the scene's world culture and age. Every operational or constructing rival building except roads gets a pennant child node: a 1×6 px dark pole and a 5×3 px triangle in the rival's colour, rendered once per colour into an `SKTexture` from code and placed at the top-left corner of the sprite's bounds, above the building in z-order. Player buildings have no pennant. Residents walking on a rival island take names from the rival's culture.

### D11 — UI

- **New Game:** a "Rival towns" toggle, visible only for the Archipelago layout in Sandbox mode, default on. Choosing Island Rivalry forces the layout to Archipelago and disables the layout picker.
- **Standings panel:** a HUD button (trophy icon) shown when the world has rivals, opening a list with one row per standing: colour swatch, name, population, age name and wealth (`$1,234`). The player's row is bold.
- **Rejection text:** `.foreignIsland(.rival(id))` reads "<Rival name>'s island — you can't build here."
- **Inspector:** on a rival building it shows the rival's name and colour above the building name, uses the rival's culture tier names, and hides Demolish.
- **Island HUD:** when the camera's island belongs to a rival, the island overlay shows "<name> (rival)" and hides the stocks row.
- **Banner:** `rivalAgeAdvanced` shows "<name> enters the <Age>".

### D12 — Migration v8 → v9

Adds `rivals: []` to the world. Buildings and ships keep their JSON; their decoders read the missing `owner` as `.player`. `SaveFile.currentVersion` becomes 9. Pending commands in old saves contain no `rivalPlace`.

## Risks / Trade-offs

- **[Risk] Rivals feel too strong or too weak.** → Mitigation: all numbers (treasury, turn interval, thresholds, caps) live on `Difficulty` and in one AI rules table; the runtime check records rival standings after 6,000 ticks on Hard.
- **[Risk] AI slot search costs too much per tick.** → Mitigation: at most one rival turn per tick on Hard (turns are staggered, D4), at most 81 blocks × 4 slots per turn, and the `canPlace` island map is computed once per turn instead of per candidate. The performance budget test runs with three rivals.
- **[Risk] Rivals stall on an island with few forests.** → Accepted: the wait-and-skip rule keeps the script moving; a stalled rival simply grows slowly.
- **[Trade-off] Rivals cap at citizens.** Their residents still reach the Modern threshold (30 houses × 6 = 180), and trade with bread and tools can come later.
- **[Trade-off] `Ship.owner` is unused by gameplay until `add-rival-trade`.** It is added now so the save format changes once.
