## Context

The #186 pacing sweep (PR #221) builds the bread, tools and luxury chains with the PlayerBot in two orders:
- the naive order builds each chain from its raw end (gardens, then producer);
- the careful order builds consumers first.

With the market on, the naive order misses the Renaissance in 31 of the 55 starts where the careful order reaches it.

A traced wreck (Hard, seed 0, single island, naive):
- the warehouse never fills;
- hops pile up to 148 while no brewery is ever built;
- bread (54) and tools (27) sit unused;
- houses can't become merchants without beer.

The player sees "Waiting for hops" only by inspecting a building that isn't even there. Nothing names the missing link.

## Goals / Non-Goals

**Goals:**
- Tell the player once, in passing, when a good piles up that nothing in town uses, and what would use it.
- Never nag a well-run town.
- Measure what following the hint saves.

**Non-Goals:**
- Wood supply and forest exhaustion. Measured as the real wood limit, it is a #186 pacing finding.
- Store caps or production priorities.

## Decisions

### D1. Measured and dropped

| Variant (market on, 60 starts) | Careful reaches | Careful bankrupt | Naive misses | Naive bankrupt (careful not) |
|---|---|---|---|---|
| Baseline | 55 | 1 | 31 | 5 |
| Charcoal burner keeps 8 wood | 44 | 11 | 24 of 44 | 4 |
| Store-full hint, followed | 55 | 1 | 37 | 1 |
| Idle-good hint, followed | 55 | 1 | 21 | 0 |

- The wood reserve starves charcoal, then tools, then merchants. By then 13–24 huts already report "no trees in reach".
- The store-full hint fires on ordinary goods (planks, bread), because the town center's 40 shared units fill with them in a healthy town.

### D2. `World.idleGoods(of:)`

A good is idle when:
- the owner's stores together hold at least `idleGoodThreshold` (20);
- no house tier of the owner's culture needs it;
- `buildableUsers(of:for:)` is non-empty, meaning kinds the owner may build now that make goods from it or burn it (projects such as the monument don't count);
- the owner owns no building of any user kind, in any state.

The result lists idle goods in catalog order, each with its users. One building of a user kind, even one under construction, silences the hint: help is on the way.

House needs are excluded because piling them up is normal. That also covers planks once metallurgy makes the toolsmith a user. A fixed 20 is checked against a careful town in D4, and raised for raw goods if it nags.

### D3. The banner

- It reuses `SessionBanner` through `show(_:)`: no pause and no new layout, so no canvas.
- `GameSession` keeps the goods it has already hinted about this session.
- It checks after each tick, only when no other banner shows, so history events and the deficit hint keep priority. It names the first idle good not yet hinted.
- Building names come from the kind's raw value ("charcoal burner"), because the palette's short labels name goods ("Charcoal").

### D4. Measuring it

- The PlayerBot's `naiveFollowingHints` order is the naive order that, while a good is idle, places its first user before anything else.
- The pacing sweep records every good hinted in each game (`hints=`), with the hint shown but ignored by every order except the hint-following one.
- The careful order's count is the false-positive rate a good player would see in 20 years.
