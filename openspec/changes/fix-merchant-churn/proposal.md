## Why

Merchants do not hold (#402). The `add-campaigns` baseline shows a town's merchants swinging between 0 and 60 within two years, which puts the era techs gated on 40 and 60 merchants (steam power, electricity) out of reach, and a 2026-10-30 playtest saw houses flip tier while the player watched.

A per-season trace of a careful bot game (Normal, single island, seed 0) shows the cause. While a town has no merchants, nothing eats bread, tools, cloth or the luxury, so the market hub fills up with them. A full citizen house moves up as soon as its hub holds one unit of each merchant need for 120 ticks. So when the last chain comes online, every full citizen house of the hub qualifies in the same 120 ticks. In the trace, 21 houses became merchants within one season (the count peaked at 128), drained the hoard within a few consumptions and fell back together: 19 of them declined, short of beer, cloth and tools. The town ended that season with 14 merchants. Supply was never the limit for those 14. The rule let in more houses than the chains could feed, all at once.

## What Changes

- **BREAKING (balance):** after a house moves up into a tier, no other house of the same market hub may move up into that tier for 100 ticks (one consumption interval). A ready house waits and moves up as soon as its turn comes, oldest house first.
- A hoard now admits houses one at a time. Each new house starts eating before the next one moves up, and porters already serve the highest tier and the oldest house first. So the hub's stock of the scarcest merchant good runs out after the town has as many merchants as its chains feed, not after twenty more. The houses beyond that never move up, so they never crash.
- Moving down is unchanged and never held back.
- Each house saves the ticks since it last moved up (`ticksSinceAdvance`, held at 100). The key is additive: an older save loads as if every house moved up long ago.

## Capabilities

### New Capabilities
<!-- None. -->

### Modified Capabilities
- `population-and-needs`: houses of one hub move up into a tier one at a time, at most one per 100 ticks.

## Impact

- **Code:** `Population.swift` (`ticksSinceAdvance`, `advanceSpacingTicks`, Codable) and `World+Population.swift` (the spacing in `updateTier`).
- **Saves:** one additive key, no version bump.
- **Determinism:** the simulation changes wherever two houses of a hub would move up within 100 ticks, so the `DeterminismFixture` baseline moves.
- **Balance:** measured with a per-season merchant trace on several seeds (design "Evidence"). The release sweeps could not run tonight because the host was overloaded (load average 600–900), so they are a follow-up.
