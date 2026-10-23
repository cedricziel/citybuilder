## Context

Nothing on today's HUD connects money to buildings. The status pill shows the balance only. Tax and upkeep are invisible until the deficit hint (#162) names them, and by then a Hard town has one tax interval left. Sandbox games have no goals and no onboarding beyond the iOS "Long-press a tile to build" coachmark.

A trace of the naive scripted player on Hard (seed 0, single island) shows the failure:

| Tick | Balance | Tax | Upkeep | Residents | Food | Buildings |
|---|---|---|---|---|---|---|
| 100 | $305 | $0 | $0 | 0 | 1 | lumberjack, sawmill, 55 road tiles |
| 1,300 | $48 | $0 | $2 | 0 | 0 | + forester, 3 houses |
| 2,400 | $4 | $0 | $2 | 0 | 0 | unchanged |
| 2,600 | −$4 | $0 | $2 | 0 | 0 | bankrupt |

It never builds a farm, because its farm rule allows none at zero houses and by three houses it can't afford one. With no food the houses stay empty and tax stays at $0.

## Goals / Non-Goals

**Goals:**
- Teach food, then planks, then houses, then tax against upkeep, then the market, during the first in-game year.
- Show the tax, upkeep and net of one collection while the player can still act on them.
- Stay out of the way: no pause, no modal, no forced steps, hideable at any time.
- Prove the advice works: a bot that follows it stays solvent and grows on Hard for five years.

**Non-Goals:**
- A scripted tutorial or camera tour.
- Changing tax, upkeep, starting stock or bankruptcy rules.
- Mid-game pacing (#186).

## Decisions

### D1. Five steps, in the order a Hard start succeeds

The bot measured four orders on Hard, seeds 0–9, both layouts, 12,000 ticks (five years). Every guided order buys at the market. Residents are counted in the player's own houses at the end:

| Variant | Bankrupt | Residents, single island (min / median) | Residents, archipelago (min / median) |
|---|---|---|---|
| none: today's naive player, no market | 20/20 | — | — |
| market only | 1/20 | 37 / 45 | 32 / 47 (solvent starts) |
| farm, 3 houses, lumberjack, sawmill | 0/20 | 39 / 57 | 31 / 48 |
| 3 houses, farm, lumberjack, sawmill | 0/20 | 49 / 56 | 32 / 52 |
| **farm, lumberjack, sawmill, 3 houses** | **0/20** | **29 / 61** | **38 / 53** |
| farm, lumberjack, sawmill, 3 houses, no market | 3/20 | 2 / 36 | 0 / 0 |

Planks before houses has the best median on both layouts and is the only order that can work without buying planks, since a house needs 4 and Hard starts with 3. Without the market even that order goes bankrupt on 3 of 20 starts and barely grows, so the market is a step, not an aside. A second farm after the houses made no difference (minimum 26), so the guide stops at one.

| Step | Met when |
|---|---|
| Build a farm | The player owns an operational farm (the only building that produces food). |
| Make planks: a lumberjack and a sawmill | The player owns an operational lumberjack hut and an operational sawmill. |
| Build 3 houses on a road | The player owns at least 3 operational houses with a road beside them (`World.isRoadConnected`). |
| Earn more tax than upkeep | One collection's tax is more than its upkeep (`World.playerTaxAndUpkeep`). |
| Sell surplus at the market | `World.market.sold` is non-empty: a sale this season. The ledger resets each season, so the latch below keeps the step met. |

Steps are checked, not enforced: the player can build anything in any order. A step is met when the world meets it as it stands, so a reloaded save shows the right checks, and once met it stays met for the session. Only the player's own buildings count. Roads are not a step of their own, but placement accepts a house with no road beside it, and such a house never fills, so the house step counts only road-connected houses.

### D2. When the guide shows

The guide shows in every game mode while a step is open, the game is not over, and the player has not hidden it this session. There is no time limit: a naive Hard start goes bankrupt early in year 2, so a guide that left after year 1 would leave just before the failure it exists to prevent.

Session state is the set of steps met so far, and whether the guide is dismissed (hidden by the player, or every step met). The latch keeps the market step met after a new season empties the ledger. Nothing is saved, which keeps CityCore and the save format unchanged; no existing stat counts lifetime market sales. Later: remember "hidden" and the met steps per save, so a reload neither brings back a hidden guide nor reopens the market step.

Debug launches with any `-uiTest…` flag start with the guide dismissed, so UI tests and art shots aren't cluttered; `-uiTestFirstSteps` keeps it.

### D3. Layout: option A plus B's caption

The Claude Design canvas put today's HUD next to three options: A, a first-steps card; B, contextual hints only; and C, first steps in the goals sheet. A plus B's caption was picked. A is the only option that shows the ledger before the deficit.

- The card is a 12 pt-radius thin-material panel under the top-right HUD buttons, 300 pt wide. It has a "First steps" headline with a hide button, a tax / upkeep / net row in monospaced figures (net in red below zero), the caption "Per collection, every 50 ticks", and five step rows with a check circle and a one-line reason each.
- On a screen narrower than 600 pt or shorter than 500 pt (`HUDLayout.collapsesFirstSteps`; iPhone landscape is 844 × 390) the card collapses to one capsule, "First steps 2/5 · net -$24", which expands when activated and reads as "First steps, 2 of 5 done, net minus 24 dollars". Every platform shows the hide button, Apple TV included, where it takes focus like the other HUD buttons.
- The tool strip warning is appended to the existing hint with " · ", as the in-reach count already is. Its upkeep is what the building would pay at its candidate site (`World.upkeepPerCollection`), so a mead hall's relief shows.
- The card's column is subtracted from the stocks tray's width and from the inspector callout's free area while it shows expanded; the collapsed capsule only lowers the free area's top.

### D4. Measuring the advice with the PlayerBot

`PlayerBot` gains `firstSteps`, an ordered list of buildings it places before anything else, buying missing wood or planks at the market when `tradesAtMarket` is set. `PlayerBot.guideSteps` is the guide's order. The sweep checks, on Hard, seeds 0–9, both layouts, 12,000 ticks:

- Guided (guide steps plus the market): never bankrupt, and at least 25 residents in the player's houses. The threshold sits below the market-only variant's worst solvent start (32) and the guided minimum (29). Population is noisy from seed to seed, so the threshold is set to catch a stalled town, not a dip. The stalled no-market guided runs end at 0–8 residents on 11 of 20 starts.
- Naive control (no steps, no market): seeds 0 and 5 on both layouts each go bankrupt. Two seeds keep the weekly job short; the full measurement had all 20 starts go bankrupt.

Both run behind `RIVAL_SWEEP=1` in the weekly `rival-sweep` job, because a five-year bot game takes about two minutes in a debug build.

## Risks / Trade-offs

- [The card covers map on iPhone landscape] → It collapses to one capsule on compact width.
- [The bot's order is one of many good openings] → The guide's steps are checked, not enforced; the sweep shows the order is sufficient, not that it is the only one.
- [Population noise could flake the sweep] → The 25-resident floor sits below every guided start measured; a failure means a stalled town.
