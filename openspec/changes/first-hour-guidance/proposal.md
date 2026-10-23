## Why

A scripted player that builds the way a newcomer might, never touching the market, goes bankrupt on all 20 Hard starts we measured (seeds 0–9, both layouts), mostly at the first collections of year 2. A trace of one game shows why. The player never builds a farm, so its houses never fill and tax stays at $0. Roads and a sawmill spend the starting money, and the sawmill's upkeep bleeds the rest. Huts are not the problem: lumberjack huts and foresters cost no upkeep. Nothing on screen says that residents need food, that only residents pay tax, or that Hard's 3 starting planks can't build a 4-plank house. The deficit hint (#162) speaks only once the treasury is negative, and its advice ("build houses before more huts") points at the wrong cause. Issue #185.

## What Changes

The first hour should teach that food leads to residents and residents lead to tax, in the order a Hard start can actually follow:

1. **Build a farm.** Farms feed residents, and empty houses pay nothing.
2. **Make planks.** A lumberjack and a sawmill, because a house needs 4 planks and Hard starts with 3. The market can buy the difference.
3. **Build 3 houses on a road.** Residents pay tax.
4. **Earn more tax than upkeep.** Shown live, before the treasury goes negative.
5. **Sell surplus at the market.** The pressure valve when cash runs low.

All of this is delivered without a tutorial wall:

- A "First steps" glass card under the top-right HUD buttons lists the five steps with check circles and shows one collection's tax, upkeep and net, with the net in red when negative. It never pauses, can be hidden, and leaves once every step is met or the first year ends. On compact widths it collapses to one line.
- While the card shows, the tool strip caption warns when a house is armed with no farm and names the upkeep of any building that has one.
- The deficit hint's advice changes to food, houses and the market.

Out of scope: a scripted tutorial, forced camera moves, new tax or upkeep rules, and mid-game pacing (#186).

## Capabilities

### New Capabilities
- (none)

### Modified Capabilities
- `platform-shells`: adds "First-hour guide" and "Tool strip warns while the guide shows"; changes the advice in "Deficit hint".
- `economy`: adds "Following the first steps keeps a Hard start solvent and growing", the balance check behind the guide.

## Impact

- **CityUI**: a `FirstStepsGuide` model on `GameSession`, the card view on the game screen, the tool strip caption, and the deficit hint text.
- **CityCore**: no source change. Everything the guide reads (`playerTaxAndUpkeep`, buildings, `MarketLedger`) is already public.
- **Tests**: `PlayerBot` gains ordered `firstSteps`; the weekly `rival-sweep` job runs the guided and naive Hard starts for five years.
- **Determinism**: none; the simulation is unchanged.
