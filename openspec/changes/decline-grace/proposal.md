## Why

A house loses a resident every 60 ticks and drops a tier after 120 ticks as soon as one of its needs is unmet (#274). A year is 2,400 ticks and a house eats every 100, so a good that is out for a single consumption interval starts the decline. Merchants have six needs, so a gap in one of them (tools, for example) brings down the town's merchants within a season. In the #273 sweeps, 6 of 20 careful Normal games ended year 10 with no merchants at all, although the same games held 20 or more merchants on average through years 8–10, and the merchants at year 10 fell from 154 to 150 games with 20 or more (mean 27.1 to 25.0).

The player also has no warning. The red "!" icon shows when a good is short, but nothing says the house is about to start losing people, or when.

## What Changes

- **BREAKING (balance):** a house declines (loses residents or drops a tier) only after one of its needs has been short for N consumption intervals in a row. Before that it is in a grace period: it stops growing, but keeps its residents and its tier.
- N is the tier's `declineGrace` in the packs, in consumption intervals, and scales with difficulty: one more on Easy, as declared on Normal, one fewer on Hard, never below 1; a tier declared at 1 waits 1 on every difficulty. A tier that declares no grace has N = 1, which is today's behaviour apart from one case: a good that left the house's reach between two draws used to start the decline at once, and now counts at the next draw (at most 100 ticks later).
- Only needs that bind the house count (cloth before Weaving does not), so Weaving cannot cut a grace short.
- A need that is met again resets its count at the next consumption that draws it in full.
- A house with no residents has nothing to protect: it keeps today's rule and drops a tier as soon as a need is unmet, so an emptied house can start again.
- A warning during the grace: the house reports a new `BuildingIssue`, `.runningShort(good, intervals:, grace:)`, for the binding need that has been short the longest. It maps to that good's existing "short" status icon (no new art, so no canvas), and the inspector's "Problem:" line reads "Short of <good>: residents will leave" during the grace and "Short of <good>: residents are leaving" once it has run out. Details lists how many intervals the need has been short out of N.
- The count is saved with the house. It is additive, with no version bump: a save without it loads with a count of 1 for each good the house was already short of.

## Capabilities

### New Capabilities
<!-- None. -->

### Modified Capabilities
- `population-and-needs`: decline waits for the tier's grace; the count resets on recovery; an empty house still falls at once.
- `difficulty-and-goals`: the grace scales with difficulty.
- `rendering-2_5d`: a house in its grace shows the short icon of the need nearest to causing decline.
- `platform-shells`: the inspector names the warning.
- `persistence-save-load`: the shortage count is saved and an older save loads without it.

## Impact

- **Code**: `Population.swift` (`shortIntervals`, its Codable), `World+Population.swift` (consumption, growth, tier checks), `World+BuildingIssues.swift`, `Difficulty.swift`, `StatusIcons.swift`, `InspectorView.swift`. The generator learns an optional `declineGrace` on `Tier` (`ItemSchema`, `Loader`, `Model`, `Validator`, `SwiftEmitter`, `pack.schema.json`, `FORMAT.md`) and `HouseTier` gets a generated `declineGrace`.
- **Saves and determinism**: additive Codable, no version bump, so it does not collide with `orders` (#277) or `handcarts` (#278), which are additive too. Behaviour with a grace above 1 changes the simulation, so the `DeterminismFixture` baseline moves; it is regenerated in its own commit.
- **Balance**: measured with the pacing, solvency and rival sweeps (design "Evidence").
- **Dependencies**: none new.
