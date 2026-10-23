## Context

Nothing on today's HUD connects money to buildings. The status pill shows the balance only. Tax and upkeep are invisible until the deficit hint (#162) names them, and by then a Hard town has one tax interval left before bankruptcy. Sandbox games have no goals and no onboarding beyond the iOS "Long-press a tile to build" coachmark. The scripted `PlayerBot` reproduces the failure: without the market it goes bankrupt in year 1 on all 20 Hard starts (seeds 0–9, both layouts).

## Goals / Non-Goals

**Goals:**
- Teach houses before huts, tax against upkeep, and the market, in that order, during the first in-game year.
- Show the tax, upkeep and net of one collection while the player can still act on them.
- Stay out of the way: no pause, no modal, no forced steps, hideable at any time.
- Prove the advice works: a bot that follows it keeps a Hard start solvent through year 1.

**Non-Goals:**
- A scripted tutorial or camera tour.
- Changing tax, upkeep, starting stock or bankruptcy rules.
- Mid-game pacing (#186).

## Decisions

### D1. Three steps, checked from world state

| Step | Met when |
|---|---|
| Build 3 houses on a road | The player owns at least 3 operational houses. |
| Earn more tax than upkeep | A collection's tax is at least its upkeep (`World.playerTaxAndUpkeep`) while the player owns at least 3 houses. |
| Sell surplus at the market | The player has sold at least one unit at a town center market this session (`MarketLedger.sold` non-empty, or a sale seen earlier in the session). |

Steps are checked, not enforced: the player can build anything in any order. A met step stays met for the session. Three houses is where the bot's tax first covers a starter hut and forester on Hard (to confirm with the measurement in D4).

Alternatives considered: a goal per building kind (too many rows; reads like a tutorial), and a single "keep your net positive" line (teaches the symptom, not the cause).

### D2. When the guide shows

The guide shows in every game mode while the date is in the game's first year, at least one step is open, the game is not over, and the player has not hidden it this session. Loading a save past year 1 shows nothing. Hiding is per session so a returning player who loads an early save sees it again; this keeps CityCore and the save format unchanged.

### D3. Layout: chosen on the canvas

The Claude Design canvas (linked from the PR) puts today's HUD next to three options:

- **A. First-steps card.** A glass card under the top-right buttons: the three steps with check circles and a tax / upkeep / net row for one collection, with the net in red when negative. A close button hides it.
- **B. Contextual hints only.** No new layout: a one-time parchment banner ("Houses pay the bills") on the first non-house placement, and the tool strip caption naming the upkeep of a building that pays no tax.
- **C. First steps as goals.** Sandbox games get the Goals button and sheet, listing the three steps, with the ledger line under the sheet.

Recommendation: **A, plus B's tool strip caption.** A is the only option that shows the ledger before the deficit, which is the thing the bot's failure says players lack. C hides the ledger behind a button, and B alone teaches only at placement time. The spec below follows A + caption; if the canvas review picks another option, the requirement text changes, and the steps and the measurement stay.

### D4. Measuring the advice with the PlayerBot

`PlayerBot` gains `followsFirstSteps`. Until it owns 3 houses it places only houses. After that, it skips any building whose difficulty-scaled upkeep would push one collection's net below zero. Market selling stays behind `tradesAtMarket`, so the sweep can separate the three steps:

| Variant | Houses first and net check | Market |
|---|---|---|
| none (today's naive player) | no | no |
| market | no | yes |
| steps | yes | no |
| all (follows the guide) | yes | yes |

The check that gates this change: on Hard, seeds 0–9 on both layouts, "all" stays solvent through tick 2,400 (year 1). It runs in the weekly `rival-sweep` job with the existing solvency sweep, next to the "none" control, because a bot year takes several seconds in a debug build.

## Risks / Trade-offs

- [The card covers map on iPhone landscape] → On compact width the card collapses to one line ("First steps 1/3 · net −$24") that expands on tap. The canvas shows iPad; the iPhone layout gets its own artboard before implementation.
- [The bot's net rule is stricter than any player] → It is the guide's advice taken literally; the sweep checks that the advice is sufficient, not that players follow it.
- [Three houses may be the wrong number on some culture or start] → The measurement runs both layouts and all seeds; the number is a constant in one place.
