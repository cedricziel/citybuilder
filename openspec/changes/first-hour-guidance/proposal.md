## Why

A scripted player that builds the way a newcomer would, huts and foresters before houses and never touching the market, goes bankrupt in year 1 on every Hard start we measured (20 of 20 games, seeds 0–9 on both layouts) and in 7 of 20 Normal archipelago games. The same player with the market goes bankrupt in 1 of 20 Hard games. The economy works; the game just never tells a new player how it works. The deficit hint (#162) only speaks once the treasury is already below zero, which on Hard leaves one tax interval of grace. Issue #185.

## What Changes

The first hour should teach three things, in this order:

1. **Houses before huts.** Only houses pay tax. Huts, foresters and sawmills only cost upkeep, so a town that builds them first pays for buildings nothing funds.
2. **Tax against upkeep.** Every 50 ticks the town collects tax and pays upkeep. The player should see both numbers and the net before it goes negative, not after.
3. **The market as a pressure valve.** Selling surplus at the town center's market turns stock into cash when the net dips.

Delivered lightly, without a tutorial wall:

- A "First steps" guide on the game screen with the three steps as checkable goals and the tax, upkeep and net of one collection. It does not pause the game, needs no input to continue, can be hidden at any time, and leaves once all three steps are met or the first year ends.
- While fewer than three houses stand, arming a building that pays no tax adds its upkeep and "pays no tax" to the tool strip caption.
- The deficit hint stays as the last line of defence.

The layout (where the guide sits, card or goals sheet) is chosen on the Claude Design canvas before UI work starts; the spec below describes the recommended option and is revised if another is picked.

Out of scope: a scripted tutorial, forced camera moves, new tax or upkeep rules, and mid-game pacing (#186).

## Capabilities

### New Capabilities
- (none)

### Modified Capabilities
- `platform-shells`: adds "First-hour guide" and "Tool strip names buildings that pay no tax".
- `economy`: adds "Following the first steps keeps a Hard start solvent", the balance check behind the guide.

## Impact

- **CityUI**: a guide view on the game screen, fed by `World.playerTaxAndUpkeep`, the player's house count and the season's `MarketLedger`; the tool strip caption; one hide flag per session.
- **CityCore**: no new state; everything the guide shows is already readable.
- **Tests**: `PlayerBot` gains a `followsFirstSteps` mode; the weekly `rival-sweep` job runs the guided Hard start for year 1.
- **Determinism**: none; the simulation is unchanged.
