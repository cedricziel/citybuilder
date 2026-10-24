## Context

`World+Economy` credits taxes and deducts upkeep on the same tick, every 50 ticks (`Economy.taxIntervalTicks`, `upkeepIntervalTicks`), and ends the game once the balance has stayed below zero for the difficulty's grace period: 150, 50 or 30 ticks. On Hard, a dip that starts at a collection runs out its 30-tick grace before the next collection at tick 50.

The #72 measurement used the #47 playtest bot: it builds by the rival AI's rules, keeps a $50 cushion, and runs 15 years on single-island and archipelago seeds 0–9. Bankruptcies before this change:

| Difficulty | Without market | With market |
| ---------- | -------------- | ----------- |
| Easy       | 0 / 20         | 0 / 20      |
| Normal     | 7 / 20         | 0 / 20      |
| Hard       | 20 / 20        | 1 / 20      |

Every failed game bottomed out at −$1 or −$2.

## Goals / Non-Goals

**Goals:**
- No difficulty ends a game before the player sees the next tax collection.
- Guard the market's role in keeping an early town solvent.

**Non-Goals:**
- Changing upkeep, costs or starting money. Doubling every grace to 100 ticks still failed the same games at −$4: those towns run real deficits, and Hard is meant to punish them.

## Decisions

### D1. Hard grace 50 ticks

50 ticks is one tax interval. The deficit counter is already 1 on the tick the balance falls below zero, so the game ends only once the counter exceeds the grace: a dip that starts on a collection tick then reaches the next collection, 50 ticks later, before the game can end. Ending it at the grace itself, as before, ended such a dip one tick before that collection. The code states every grace in whole tax intervals (3, 1 and 1), so the rule holds if the interval changes. Hard stays the strictest difficulty in practice, because a Hard town's upkeep is 125%.

### D2. A scripted bot in the test target

The bot is the #47 playtest bot: the rival AI's opening and growth loop and town plan (`RivalAI`, `RivalTownPlan`) for the player, with the simple threshold rules the rivals had then, plus the market trades in the requirement. It keeps those rules on purpose, so its numbers stay comparable with #47 and #72. It lives in the test target only, as test support.

- The sweep plays seeds 0–9 on both layouts for 36,000 ticks with the market.
- A control plays archipelago seeds 0 to 29 for 4,000 ticks with and without the market: at least 2 of 30 must go bankrupt without it and at most 1 with it, so the sweep fails loudly if it stops testing what the market does. It first named four seeds that went bankrupt; `rest-when-stocked` saved two of them, and picking new failing seeds would bend the control to the result, so it counts over all 30 instead.
- Both run behind `RIVAL_SWEEP=1`, the flag the rival sweep already uses, in the weekly `rival-sweep` workflow.
- None runs in the default suite. No Normal seed among the first 50 goes bankrupt without the market before tick 3,400, and a 3,500-tick bot game takes about 2 minutes in a debug build, so a check with a control cannot fit a CI budget of a minute. The rule defect itself is guarded in the default suite by "A dip on a collection tick sees the next collection".

## Evidence

Same bot, single-island and archipelago seeds 0–9, 36,000 ticks. "Before" is grace 30 on Hard with the game ending at the grace; "after" is grace 50 with the game ending once the deficit outlasts it.

| Bankrupt               | Before  | After   |
| ---------------------- | ------- | ------- |
| Hard, without market   | 20 / 20 | 20 / 20 |
| Hard, with market      | 1 / 20  | 1 / 20  |
| Normal, without market | 7 / 20  | 7 / 20  |
| Normal, with market    | 0 / 20  | 0 / 20  |

The outcomes don't change. Every failed game bottoms out at −$1 or −$2 and stays there through the next collection, because its upkeep exceeds its tax: a real deficit, which Hard is meant to punish. The change removes the rule defect, a dip ending the game before the next collection could lift it, not those deficits.

## Risks / Trade-offs

- **Hard is slightly more forgiving.** A Hard player now gets one tax collection to recover from a dip, as on Normal.
- **The bot is test code that follows `RivalAI`.** A change to the rival rules changes the bot too. The short test then tells whether the market still keeps such a town solvent.

## Migration Plan

None: the grace is read from the difficulty, so saves pick up the new value.
