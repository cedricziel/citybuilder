## Why

`add-culture-content` gives each culture its own luxury chain, but once merchants have their beer, wine, tea or coffee, every culture plays the same game. The game direction asks for one signature mechanic per culture: a building that only that culture has and that changes a decision the player makes, such as where to build, what to do with surplus goods, or whether the luxury goes to merchants or to the signature building.

This change depends on `add-culture-content` (luxuries, culture-only buildings) and `add-age-signatures` (fuel, ranges, range rings), and lands after both.

## What Changes

- **One signature building per culture**, culture-only and available from the start of the game in every age:

  | Culture | Building | Effect | Served with the luxury |
  |---|---|---|---|
  | Northern European | mead hall | other buildings within 8 tiles pay half upkeep | beer: they pay no upkeep |
  | Mediterranean | forum | houses within 8 tiles pay +1 tax per resident | wine: +2 per resident |
  | East Asian | temple garden | citizens and above within 6 tiles produce +1 knowledge per resident every 100 ticks | tea: +2 per resident |
  | Middle Eastern | caravanserai | a caravan sells up to 4 units of a chosen export good every 100 ticks at base price | coffee: up to 8 units |

- **Served luxury:** each signature building takes 1 of its culture's luxury every 100 ticks through the fuel mechanism from `add-age-signatures`. While served, its effect doubles. Without the luxury it still works at the base rate. The luxury now has two uses, merchants and the signature building, and the player decides how to split it.
- **Culture rule:** the four buildings belong to their culture and use the placement rule and palette filter from `add-culture-content`.
- **Caravanserai export:** a new command picks the export good (or none). Supply carriers bring it in up to 8 units, but only while the island's goods buffers keep more than 10 of it. Caravans sell what the caravanserai holds, the export good first. The caravanserai can't export coffee, its own luxury.
- **Base prices:** caravans sell at `Good.basePrice`, the table from `add-rival-trade` (wood $4, planks $8, food $4, bread $12, grain $3, flour $6, ore $5, charcoal $5, iron $14, tools $30). This change adds the culture goods: hops, grapes, tea leaves and coffee cherries $3; beer, wine, tea and coffee $16. If this change lands before `add-rival-trade`, it adds the whole table and `add-rival-trade` reuses it.
- **UI:** inspector lines for each building, an export picker on the caravanserai, range rings (mead hall and forum 8, temple garden 6), and a "<Kind> is out of <good>" banner.
- **Art:** four buildings, each in its culture's style in the procedural sprite kit.
- **Saves:** no migration. `Building.exportGood` decodes as none when missing, and the new command case only appears in new saves.

Deferred: caravans walking the map, caravan destinations and moving prices, caravans trading with rival towns, a second signature per culture, rival towns building culture signatures.

## Capabilities

### New Capabilities

- `culture-signatures`: the four culture signature buildings, served luxuries, the caravanserai's export and caravans.

### Modified Capabilities

- `buildings-and-construction`: four culture buildings.
- `goods-and-production`: base prices for the culture goods.
- `economy`: forum tax, mead hall upkeep, caravan income.
- `research`: temple garden knowledge.
- `rendering-2_5d`: range rings and served-state animation for the four buildings.
- `platform-shells`: inspector lines, export picker, out-of-luxury banner.
- `sprite-style-catalog`: four buildings.

## Impact

- **CityCore:** four `BuildingKind`s with `culture` and `fuel`, catalog specs, `Good.basePrice` entries for the culture goods (or the whole table), `Building.exportGood` with tolerant decoding, `Command.setExport`, export supply with the island reserve, caravans in `runSignatureSystem`, `WorldEvent.caravanSold`, forum tax, mead hall upkeep, temple knowledge.
- **CityRender2D:** range ring radii and served-state animation for the four kinds.
- **CityUI:** inspector sections, export picker, banner text by fuel good.
- **Art:** four buildings in `buildings.py` and four catalog entries.
- **CityPersistence:** none.
