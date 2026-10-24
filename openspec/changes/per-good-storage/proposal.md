## Why

A town center, warehouse or port holds one pool shared by every good. A good nobody uses yet fills it and starves the rest. The typical case: bakeries fill the warehouse with bread before any merchant eats it. Iron then has nowhere to go, no tools get made, and no merchant ever arrives.

On main this overflow is hidden, because a carrier that finds its store full drops its goods. That loss works as an accidental cap. #232 (visible-distribution M1) makes goods lossless and hops them straight to consumers, and the hidden cap stops working:
- main: 121 of 180 pacing arms reach a merchant;
- #232: 25 of 180, with bankruptcies rising from 13 to 49.

`rest-when-stocked` rests a producer whose stores hold plenty, but only while another kind of building shares its inputs, so a bakery never rests. A variant that also rested producers of goods only houses use made main worse: 84 of 180 arms reached a merchant, with 31 bankruptcies.

The owner's model removes the cause instead:
- each store holds each good separately;
- output leaves a producer only when something can take it.

## What Changes

- **Stores hold each good separately.** Town centers, warehouses and ports hold up to a per-good limit set in the pack (`storagePerGood`): 40 for the town center, 80 for the warehouse and the port. Producer and house stockpiles keep one shared capacity.
- **Producers ship only where there is room.** A producer's output leaves only for a waiting construction site, or for a store with room for that good. Room counts the units already on their way, so it is never promised twice. Otherwise the output stays put, nothing is lost, and the producer stops when its own stockpile is full. It resumes as soon as room opens.
- **Output stuck is a building issue.** "Output stuck: no room for bread" replaces "Store full". It names the good, so the status icons can show it.
- **The rest rule goes.** `restAt`, the resting check and the resting issue are removed: per-good limits cap every good without them (design D4, measured).
- **Everything that reads room reads it per good.** This covers market purchases, ship unloads, rival port trades, the bountiful harvest, rival purchases and the island summary's capacity.
- **Rival rules change.** A rival builds its first warehouse when its town center has no room for food. It sells surplus planks or wood when its stores have room for fewer than 20 more of that good. The "clear a full town center" sale and the "no purchase into a full town center" rule can no longer fire, so they are removed.
- **The no-market control changes.** With no store clog, towns no longer go bankrupt without the market. The control in `hard-bankruptcy-grace` now checks that the market makes no town worse off (design D9). This amends that active change's scenario in place.
- **Research is retuned** so Normal stays at 6–8 years to the Renaissance (design D6).
- **Saves move to version 10.** Each store takes its per-good limit and keeps every unit it holds, overflow included, until the overflow is used.

## Capabilities

### New Capabilities
- (none)

### Modified Capabilities
- `warehouses-and-logistics`: stores hold each good separately; producers ship only where there is room; "Buildings report what stops them" replaces "Buildings report why they are idle".
- `goods-and-production`: the rest requirement is removed.
- `platform-shells`: the inspector loses the resting line.
- `port-and-shipyard`, `sea-transport`, `rival-trade`, `town-market`, `calendar-and-events`: room is per good.
- `rival-towns`: the warehouse trigger and market trades read room per good.
- `research`: retuned costs.
- `persistence-save-load`: saves before per-good storage keep their stock.
- `economy` (in the active `hard-bankruptcy-grace`): the no-market control's scenario becomes "The market does not make towns worse off".

## Impact

- **Game data:** a `storagePerGood` building field, which GameDataGen learns, exclusive with `storage`. `restAt` is removed from goods and from GameDataGen.
- **CityCore:**
  - `Stockpile` gains a per-good mode and `room(for:)`.
  - Carrier destination choice reserves room per good.
  - `BuildingIssue.outputStuck(Good)` replaces `.storageFull`. `.resting` is removed.
  - The rest rule's code is removed.
  - Rival, market, ship and harvest code reads room per good.
- **CityPersistence:** a v9 → v10 migration and a v9 fixture.
- **CityUI / CityRender2D:** inspector text, the market's buy button, and status icon mapping (art2's StatusIcons switch).
- **Sequencing:** this lands on main first, without hops. #232 then merges main and is re-measured on top. The active changes `rival-surplus-sales`, `rival-viability-margin` and `market-buys-use-island-stores` must archive before this one, since this change replaces requirements they modify.
