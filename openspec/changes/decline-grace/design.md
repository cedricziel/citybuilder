## Context

`runPopulationSystem` visits each house every tick. Every 100 ticks (`consumptionIntervalTicks`) a populated house draws each need of its tier from the buffers on its road network, and `shortGoods` records the goods it could not draw in full. A need is satisfied while a buffer holds the good and the last draw was not short. The house shrinks by one resident 60 ticks after any binding need is unsatisfied, and drops a tier after 120 ticks of the same. So one failed draw, 100 ticks, is enough to start the decline, and the next successful draw is 100 ticks later.

#273 added cloth, a sixth merchant need, and measured the effect: 6 of 20 careful Normal games had no merchant at the end of year 10 (10 of 180 over all arms), while 150 of 180 games held 20 or more (154 before the chain). Merchants arrive late and drain fast.

## Goals / Non-Goals

**Goals:**
- One short interval of one good does not cost a town its merchants.
- The player sees the danger before the decline starts.
- Merchant retention at year 10 returns to at least the pre-wool level, the Normal careful Renaissance stays at 6–8 years and bankruptcies stay at 0.

**Non-Goals:**
- Changing growth, advancement, consumption rates or what makes a need met.
- A new icon or look. The warning reuses the per-good "short" icon.
- A cap on how long a good may stay short: a shortage that lasts through the grace declines exactly as today.

## Decisions

### D1. Count short consumption intervals per good

`HousePopulation.shortIntervals` maps a good to the number of consumption intervals in a row in which the house drew less than it needed. Each consumption of a good sets it to `previous + 1` when the draw is short and removes it when the draw is in full, so recovery resets the count at the next consumption (at most 100 ticks after the good returns). The count saturates at 255. Goods that are not needs of the house's tier are dropped at each consumption and when the tier changes, so a stale count cannot be inherited by a higher tier.

A house is **past its grace** when any binding need has a count of at least N. Only then do the two decline rules apply (a resident every 60 ticks, a tier after 120). While a need is unmet but the house is not past its grace, growth stays blocked (it needs every binding need met) and nothing else changes.

Alternative: count ticks of unsatisfied need. Rejected: satisfaction flips between consumptions (`inReach` is checked every tick), so a tick count would depend on when the good arrives within the interval; the consumption interval is the rate at which a house actually eats, and the issue asks for it.

Alternative: a single timer per house. Rejected: one good recovering would have to reset it while another is still short, and the inspector could not name the need nearest to causing decline.

### D2. Empty houses fall at once

A house with no residents eats nothing, so no count can grow. Rather than carry a count through an empty house (and through a save), a house with `population == 0` is past its grace as soon as a binding need is unsatisfied, which is today's rule. A merchant house that emptied only does so after its grace, so it drops a tier 120 ticks later and can start again.

### D3. N in the packs, scaled by difficulty in code

`Tier` gets an optional `declineGrace`, a positive integer of consumption intervals, default 1. The generator emits `HouseTier.declineGrace`. Difficulty adjusts it in `Difficulty.declineGraceIntervals(base:)`: Easy `base + 1`, Normal `base`, Hard `max(1, base - 1)`. The existing difficulty knobs (research cost, upkeep, bankruptcy grace) are also code, keyed by the enum; the pack states the Normal value, which is the one a modder reasons about.

A default of 1 keeps every pack that does not mention the field exactly as before (a third-party pack, the generator's fixtures).

Alternative: a `Difficulty` item kind in the packs. Rejected: it is a new generator kind for one number, and difficulty stays an enum in code everywhere else.

Alternative: one global N. Rejected: peasants have one need and merchants six, and the sweeps may want different values.

### D4. The warning is a building issue

`BuildingIssue` gets `.runningShort(Good, intervals: Int, grace: Int)`, so the inspector needs no more than the issue. `World.buildingIssues()` reports it for a player house with residents whose binding needs include one with a count of 1 or more: the one with the largest count, ties in the tier's need order. The issue is declining once `intervals` has reached `grace`. It comes after the house's road checks, so a missing road still wins.

`StatusIcons.textureName(for:)` is exhaustive over issues, so the new case has to choose an icon: `short(good)`, the good on a cream disc with a red "!". The icon shows from the first short interval, which is before any decline, and stays through the decline. The inspector's "Problem:" line carries the message, so the existing building-problem banner ("House has a problem") names it once per distinct text. The text holds no countdown, so the banner is not raised again at every interval.

Alternative: a new icon for the grace. Rejected: the existing "!" already means "this need is short"; it needs no canvas, and the text distinguishes the two phases.

Alternative: leave the icon logic as is (it shows the first short good by `Good` order). Kept as a fallback for needs that are short but not binding, such as cloth before Weaving. The issue takes precedence, as every issue does.

### D5. Saves

`shortIntervals` is encoded as a list of good and count pairs sorted by good, and decoded with `decodeIfPresent`. A save without it gets a count of 1 for each good in its `shortGoods`, so a house that was mid-shortage starts its grace when it loads and is not punished for the format change. There is no version bump: the field is additive, the change would otherwise take a number that `orders` and `handcarts` also want, and the older save needs nothing it cannot derive.

### D6. Determinism

The count is plain integer state updated in the house loop, which already visits houses in id order. The dictionary is only read by key, and it is encoded sorted. The `DeterminismFixture` output changes once the packs declare a grace above 1; the baseline is regenerated in its own commit and checked on macOS and in CI on Linux. CityCore stays framework-free.

## Evidence

(Recorded in the PR: the pacing, solvency, control and rival sweeps on `main` and with this change, for each N tried.)

## Risks / Trade-offs

- [A longer grace lets a town that is really failing hold on] → The count resets only when the need is met, so a shortage that outlasts the grace declines as before, only later; the sweeps check bankruptcies and the Renaissance year.
- [Slower decline makes the Normal Renaissance later or earlier] → It only affects houses already in trouble, but the sweeps measure the Normal careful Renaissance against the 6–8 year goal.
- [Rivals' houses also get the grace] → They share the code path; the rival viability sweep is run before and after.
- [An older build reading a newer save ignores the count] → It just applies the old rule; nothing else in the save changes.
