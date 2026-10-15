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

50 ticks is one tax interval: the shortest grace that always sees the next collection. It keeps Hard the strictest difficulty in practice, because a Hard town's upkeep is 125%.

### D2. A scripted bot in the test target

The bot follows the rival AI's threshold rules and script (`RivalAI`, `RivalTownPlan`) for the player, plus the market trades in the requirement. It lives in the test target only, as test support.

- The CI test plays archipelago seeds 1, 2 and 3 on Normal for 2 years. Without the market, all three go bankrupt within those 2 years, so the test fails if the market stops rescuing the town.
- The sweep plays seeds 0–9 on both layouts for 36,000 ticks behind `RIVAL_SWEEP=1`, the flag the rival sweep already uses, and runs in the weekly `rival-sweep` workflow.

## Evidence

Hard, same bot and seeds, grace 30 → 50 ticks: recorded in the PR.

## Risks / Trade-offs

- **Hard is slightly more forgiving.** A Hard player now gets one tax collection to recover from a dip, as on Normal.
- **The bot is test code that follows `RivalAI`.** A change to the rival rules changes the bot too. The short test then tells whether the market still keeps such a town solvent.

## Migration Plan

None: the grace is read from the difficulty, so saves pick up the new value.
