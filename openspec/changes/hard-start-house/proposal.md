## Why

A house costs 4 planks, but a Hard town center starts with 3 (#303). A new Hard player cannot build a first house without trading at the market, which the fire-season playtest (playtests/2026-10-29-fire-season.md) hit straight away.

## What Changes

- **BREAKING (balance):** Hard's starting stock rises from 3 to 4 planks, enough for one house. Wood, food and money are unchanged, so Hard still starts below Normal (5 planks).
- Rivals start with the difficulty's starter stock, so a Hard rival also gets 4 planks.
- A new scenario: every difficulty starts with the planks for a house.

## Capabilities

### New Capabilities
- (none)

### Modified Capabilities
- `difficulty-and-goals`: "Difficulty" sets Hard's starting planks to 4.
- `rival-towns`: "Rival identity" scenario names 4 planks.

## Impact

- **CityCore**: `Difficulty.starterStock`.
- **Determinism**: the `DeterminismFixture` plays Hard, so its output changes; the macOS/Linux compare is unaffected.
- **Campaigns**: chapter starts set their own stock and are out of scope.
