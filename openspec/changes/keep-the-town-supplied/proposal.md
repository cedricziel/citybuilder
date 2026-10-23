## Why

The #186 pacing sweep found that a player who builds each mid-game chain from its raw end often stalls. Issue #224.
- Hop gardens come before the brewery, grain farms before the mill. The raw good piles up while the building that would use it never comes.
- In a traced wreck, hops reach 148 with no brewery, while bread (54) and tools (27) wait unused. Houses can't reach merchants without the luxury.
- Nothing tells the player. Each blocked building says why only in its own inspector.

With the market on, a scripted player building each chain from its raw end misses the Renaissance in 31 of 60 starts where a consumer-first order reaches it, and goes bankrupt in 5 more.

Two first ideas were measured and dropped:
- A wood reserve for the charcoal burner made the consumer-first order worse: Renaissance in 44 of 60 instead of 55, and 11 bankruptcies instead of 1. The wood shortage is forest exhaustion, not the burner's priority. It is a pacing finding for #186.
- A "store full" hint named the wrong goods (planks, bread), and following it raised the misses from 31 to 37.

## What Changes

- **Idle-good hint:** the first time in a session that a good piles up (20 or more) while the town has no building that uses it, though the player could build one, the game shows a banner. For example: "Nothing uses your hops: Build a brewery for it, or sell hops at the town center's market."
  - Goods houses consume (food, planks, bread, tools, the luxury) never count.
  - It is a regular session banner in the existing style. It doesn't pause, and shows once per good per session.
- CityCore reports idle goods through one read-only query, `World.idleGoods(of:)`, which the hint and the scripted player share.

A scripted player that follows the hint misses the Renaissance in 21 of the 31 starts (down from 31), and its extra bankruptcies drop from 5 to 0. The consumer-first order's results are unchanged.

Out of scope: wood supply and forest exhaustion (#186 pacing), store caps, production priorities.

## Capabilities

### New Capabilities
- (none)

### Modified Capabilities
- `platform-shells`: adds "Idle-good hint".

## Impact

- **CityCore:** a new public `World.idleGoods(of:)` query. The simulation is unchanged.
- **CityUI:** `SessionBanner.swift` notes the hint after each tick.
- **Tests:** the PlayerBot gains a naive order that follows the hint, and the pacing sweep records the goods each game was hinted about.
