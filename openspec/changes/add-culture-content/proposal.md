## Why

Cultures look different since `add-cultures`, but they play the same. The game direction asks for each culture to have its own buildings and goods, so that choosing a culture changes what the player builds and what their richest residents want.

## What Changes

- **A luxury per culture:** each culture's merchants need one more good, made by a two-building chain only that culture can build:

  | Culture | Raw | Producer | Luxury |
  |---|---|---|---|
  | Northern European | hops (hop garden) | brewery | beer |
  | Mediterranean | grapes (vineyard) | winery | wine |
  | East Asian | tea leaves (tea garden) | tea house | tea |
  | Middle Eastern | coffee cherries (coffee grove) | roastery | coffee |

  Gardens produce 1 raw every 40 ticks; the producer turns 2 raw into 1 luxury every 50 ticks. Merchants eat 1 luxury per 8 residents per consumption interval, like tools.
- **Culture-only buildings:** the eight new buildings are tied to their culture. Other cultures can't place them, and the palette hides them.
- **Merchants' needs per culture:** food, planks, bread, tools and the culture's luxury. Houses that lack the luxury lose merchant status the same way they do for tools.
- **Research:** a new Medieval tech, **Cultivation** (50 knowledge), unlocks the culture's garden and producer.
- **Art:** the eight buildings in their culture's style and the eight new goods icons.
- **Saves:** existing saves gain the new goods' satisfaction flags through the tolerant house decoder; no version bump is needed because new stockpile goods default to zero.

Signature mechanics per culture follow in `add-culture-signatures`.

## Capabilities

### New Capabilities

- `culture-content`: culture luxuries, culture-only buildings and Cultivation.

### Modified Capabilities

- `population-and-needs`: merchants' needs depend on culture.
- `goods-and-production`: eight goods and four recipe pairs.
- `buildings-and-construction`: eight buildings and the culture placement rule.
- `platform-shells`: hidden foreign-culture palette entries, inspector needs by culture.
- `sprite-style-catalog`: eight buildings and eight icons.

## Impact

- **CityCore:** `Good` gains hops, beer, grapes, wine, teaLeaves, tea, coffeeCherries, coffee; eight `BuildingKind`s with `culture`; `Tech.cultivation`; `HouseTier.needs(in:)`; consumption by culture; `PlacementRejection.wrongCulture`.
- **CityUI:** palette filter and inspector.
- **CityRender2D / art:** sprites and icons.
