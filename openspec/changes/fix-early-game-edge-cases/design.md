## Context

`economy.gameOver` is set by the economy system once the bankruptcy grace runs out. The economy system then stops (`guard !economy.gameOver`), but `World.tick` still drains and applies every queued command. Placement usually fails because the balance is negative and `charge` refuses, yet demolish, forest clearing, research, routes, commissions and exports all go through, and a trade caravan can lift the balance enough for placements to succeed again.

History events are decided by `historyEvent(forYear:)` from the seed and year, then applied by `applyHistoryEvent`. Rats halves food in every operational player goods buffer and always emits `historyEvent(.ratsInTheGranary)`, even when every buffer holds zero food.

## Goals / Non-Goals

**Goals:**
- A lost game stops responding to player commands.
- Rats is never announced when it has nothing to spoil.

**Non-Goals:**
- Stopping the other systems after game over (production, population and rivals keep ticking; the UI owns what the player sees).
- Changing how events are decided per seed and year, or their weights.
- A similar "no effect" guard for bountiful harvest with full stores.

## Decisions

**D1 — Drop commands when applied, not when enqueued.** `World.tick` skips player commands while `economy.gameOver` is set. Alternative: refuse in `enqueue`. Rejected because a command enqueued just before the tick that ends the game would still apply on the next tick; checking at application covers every order and leaves `pendingCommands` unchanged.

**D2 — Drop silently.** A dropped placement emits no `placementRejected`. Alternative: emit it so the UI can play the reject sound. Rejected because the persistent game-over banner (D6) explains why nothing happens, and one rule ("no world change, no events") is easier to test and to reason about under replay.

**D3 — Rival placements still apply.** `rivalPlace` is the AI's own turn; the bankruptcy is the player's. Alternative: freeze every command. Rejected as out of scope; rivals keep ticking like every other system.

**D4 — Rats is skipped, not re-drawn.** When rats is decided and no operational player goods buffer holds food, the year passes with no event. Alternative: draw another event. Rejected because it shifts the per-year odds of the good events and needs a second draw. A skipped year keeps `historyEvent(forYear:)` a pure function of seed and year, so "Easy has no rats" and "Same seed and year give the same event" hold unchanged.

**D5 — The food check lives in the calendar system.** `applyHistoryEvent` stays an unconditional apply, which existing tests rely on; the calendar system checks whether rats would spoil anything before applying and emitting.

**D6 — The game-over banner is derived from world state, not from the `gameOver` event.** `GameSession.banner` returns the bankruptcy banner whenever `economy.gameOver` is set, ahead of any timed banner, and it never expires. Alternative: show it on the `.gameOver` event like other banners. Rejected because that event fires once, so a lost game loaded from a save would show nothing, and a 60-tick timer would leave the player without an explanation afterwards. The banner reuses the existing parchment `SessionBannerView` so it matches the other announcements.

**D7 — Tools are gated in `GameSession` and disabled in the views.** While the game is over, `selectTool` only accepts inspect, taps and drags never enqueue place or demolish, long-press opens no tile menu, no pending placement starts, and `chooseResearch` enqueues nothing. The `.gameOver` event clears any armed tool, pending placement and tile menu request. The build rail and the research button are disabled and dimmed so the player sees they are off. Alternative: rely on the core dropping commands (D1). Rejected because a tool that arms and then silently does nothing is the confusion this change is fixing. The inspector's Demolish stays as is; the core drops it, and the inspector is being reworked separately.

**D8 — Rats needs 2 food in one store.** Rats withdraws `food / 2` per store, so a store with 1 food loses nothing. The check is "some operational player store holds at least 2 food", which is exactly "rats would remove something".

### Framework-free invariant

The CityCore changes are plain Swift (`World.swift`, `Calendar.swift`) with no new imports; the banner and tool gating live in CityUI. `scripts/check-no-apple-ui-imports.sh` is unaffected.

### Determinism

Both checks read only deterministic `World` state (`economy.gameOver`, stockpiles), and neither consumes the world RNG. Two replays of the same inputs still produce byte-identical worlds and event logs. The determinism fixture's output can differ from before for seeds where rats lands on an empty granary; macOS and Linux still agree with each other.

## Risks / Trade-offs

- [A path to a player command that the UI gating misses, such as the inspector's Demolish] → The core still drops it (D1), and the banner explains why nothing happens.
- [Fixture output changes] → Expected; CI compares the two platforms with each other, not with a stored golden file.
