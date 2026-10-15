## Context

See proposal.md for why. After `game-data-codegen` M4, `add-forestry` and `add-town-market`, the state is:

- `Packages/CityCore/Sources/CityCore/Population.swift` declares `enum HouseTier: UInt8` with raw values 1, 2 and 3, and four exhaustive `switch` tables: `capacity`, `needs`, `taxPerResident` and `displayName`. The raw value is what saves store for a house's tier, and the house sprites use it in their names (`building-house-tier2-…`).
- `HousePopulation.consumption(of:in:)` has rates for food (1 per 2 residents), planks (1), bread (1 per 4) and an explicit list for tools and the four luxuries (1 per 8). Any other good returns 0.
- `World+Population.swift` updates satisfaction for `HouseTier.merchants.needs(in:)`, on the assumption that the merchants' list contains every other tier's needs.
- `Culture.swift` keeps `HouseTier.needs(in:)` (merchants add the culture's luxury) and `displayName(in:)`, which forwards to the generated `Culture.tierName(_:)`. The generator builds that function from each culture's required `tiers` map, and validates tier ids (in `tiers` and in era gates) against a hard-coded `houseTiers` list in `GameDataModel`.
- The `Good` kind has `id`, `name`, `unit`, `basePrice` and an optional `market`; `Building` has an optional `plantTicks`.
- "Every good has a consumer" (`game-data-codegen` D10) is a CityCore test over the generated catalogs plus the hand-written `HouseTier.needs`.

## Goals / Non-Goals

**Goals:**
- Tier capacity, tax, needs and default display name live in the packs. A pack adds a consumer good, and demand for it, with no Swift edits.
- The shipped game behaves byte for byte as before: same tier values, same need order, same raw values, same `DeterminismFixture` output.

**Non-Goals:**
- Consumption rates as data. The rates stay in Swift (D6).
- Advancement, decline, growth, satisfaction and tax rules. They stay in Swift.
- Culture luxuries as `neededBy`. Merchants keep adding their culture's luxury in `HouseTier.needs(in:)`, because the luxury depends on the player's culture and a tier's generated needs do not.
- Supporting a pack that removes or renames a shipped tier. Hand-written code names `peasants` (new houses, sprites) and `merchants` (the luxury), so those cases must exist; the compiler reports their absence.

## Decisions

### D1. A `Tier` kind, ordered like every other kind

A `Tier` item has `id`, `name`, `capacity`, `taxPerResident` and `needs`, all required:

```yaml
- kind: Tier
  id: citizens
  name: Citizens
  capacity: 6
  taxPerResident: 2
  needs: [food, planks]
```

The three tiers go in `core.yaml`, after the goods. Case order is load order (`game-data-codegen` D5), and the generator gives each case the raw value of its position, starting at 1. That keeps today's raw values (peasants 1, citizens 2, merchants 3), which saves store and `next`/`previous` step through.

`needs` is the tier's complete list; tiers do not inherit their predecessor's needs. That matches today's lists (`[food]`, `[food, planks]`, `[food, planks, bread, tools]`), so the packs read the same as the spec table. The validator requires `capacity` > 0 and `taxPerResident` ≥ 0, every need to be a declared good, and no good twice in one list.

*Alternatives considered:*
- **An explicit `level` field for the raw value.** It would protect saves against a reordered pack, but it is the only kind that would need one, and `next`/`previous` would then have to handle gaps. A reorder is caught by the parity scenario (D7) and the save fixtures instead.
- **Inherited needs** (each tier lists only what it adds). Shorter, and a `neededBy: [citizens]` would reach merchants for free. But the merged list's order would then depend on two rules, and the spec table lists complete needs per tier. Rejected for readability; a pack that wants a good at two tiers names both.

### D2. `neededBy` on goods merges into tier needs in load order

A good can declare `neededBy: [merchants]`. After every pack is loaded, the generator appends each such good to each named tier's `needs`, visiting goods in load order. A tier's final list is therefore its own `needs` in written order, then the goods that name it, in `Good.allCases` order. Need order drives consumption order from shared buffers, so it is deterministic and visible in the generated Swift.

The validator rejects a `neededBy` entry that names no declared tier, and a good that is already in the tier's list (written there or named twice). This is the same "reference from the new item to the existing one" rule as `unlockedBy` (`game-data-codegen` D2), so a pack never edits `core.yaml` to add demand.

*Alternatives considered:* a `kind: TierNeeds` patch item, or allowing a pack to redeclare a tier. Both point from new content at an existing item and would need merge rules for every field. Rejected.

### D3. What is generated, and what stays hand-written

| Generated (`Generated/HouseTier+Generated.swift`) | Hand-written (stays) |
|---|---|
| `enum HouseTier: UInt8, Codable, Sendable, CaseIterable` with raw values from D1 | `Comparable`, `next`, `previous` (extension in `Population.swift`) |
| `capacity: UInt32`, `needs: [Good]` (after the D2 merge), `taxPerResident: Int64`, `displayName: String` | `needs(in:)`, `displayName(in:)` (`Culture.swift`), `HousePopulation`, the population system |

`Population.swift` keeps `HousePopulation` and the hand-written extension, and loses its four tables. Callers do not change: the generated property names and types are today's.

The generator's model replaces the hard-coded `houseTiers` list with the loaded tiers, so era gates and culture tier names are checked against what the packs declare.

### D4. Culture tier names become an optional override

`tiers` on a `Culture` becomes optional, and so does each key in it. The generated `Culture.tierName(_:)` stays one exhaustive `switch` over every (culture, tier) pair: each value is the culture's override when it has one, and the tier's `name` otherwise. Emitting the full table, rather than overrides plus `default:`, avoids an unreachable `default` when every pair is overridden and keeps the generated diff readable.

The validator rejects a `tiers` key that names no declared tier. Northern European's map equals the default names, so the pack drops it; the generated Swift does not change.

### D5. The good-consumer check moves into the generator

With tier needs in the packs, every consumer is data: recipe inputs, construction materials, each culture's luxury good, and tier needs after the D2 merge. The validator rejects a good that none of these name, with the pack and the good, and suggests `neededBy`. The CityCore test "Every good has a consumer" is deleted; the scenario is now a `GameDataGenTests` test, next to one for the rejection. `game-data-codegen` D10 anticipated this move.

Market selling (`add-town-market`) does not count as consumption: a good the player can only sell back is still a dead end in the chain.

### D6. A need without its own rate is eaten at 1 per 8 residents

`HousePopulation.consumption(of:in:)` keeps its rates for food, planks and bread, and its guard that a good outside the tier's needs is eaten at 0. The explicit list `.tools, .beer, .wine, .tea, .coffee` becomes the `default:` branch. For the shipped content this changes nothing: those five goods are the only needs without their own rate, so the old `default: return 0` was unreachable for a need. Without this, a pack-added need would be required for growth but never eaten.

Satisfaction is updated for the union of every tier's needs in `culture`, in `Good` order, instead of the merchants' list. For the shipped tiers the union equals the merchants' list, and `satisfiedGoods` is a set, so saves and determinism are unchanged. Without this, a need added only to citizens would never be marked satisfied.

*Alternative considered:* a per-good `consumption` field in the packs. That is the natural next step, but rates are a balance decision with their own spec scenarios, and the proposal keeps consumption in Swift. Deferred (Open Questions).

### D7. Parity is a lasting scenario, behaviour is checked against a baseline

The spec table in "Houses have a population tier" already fixes capacity, needs and taxes. The scenario "Shipped tiers keep their values" turns it into a CityCore test over the generated `HouseTier`: case order and raw values, capacity, the need lists in order (`food`, `planks`, `bread`, `tools`), tax per resident, the default display names, and every culture's tier names. It is written against today's hand-written tables first, so it is green before the switch and must stay green after. Unlike `game-data-codegen` D8 it is not deleted afterwards, because it states the spec's table. It is a characterisation test, so it starts green; the generator scenarios and the consumption-rate scenario are the ones written red first.

Values do not prove behaviour, so M1 records `DeterminismFixture` at its default length and at 36000 ticks with `SWIFT_DETERMINISTIC_HASHING=1` on unchanged `main`, under `openspec/changes/tier-needs-data/baseline/`. After M2 the output must equal it byte for byte, on two runs.

### Framework-free invariant

The generated `HouseTier` file imports only Foundation, like the other generated files, and `check-no-apple-ui-imports.sh` scans it. `GameDataGen` stays a build-time tool that CityCore does not depend on.

### Determinism

The generated values equal today's, in the same order: `HouseTier.allCases`, raw values and every `needs` list are fixed by D1 and D2, and checked by D7. Consumption walks `needs(in:)` in that order, so buffers drain identically. D6 changes code paths only for goods the shipped tiers do not need. A pack that adds a need changes need lists and therefore advancement, and regenerates the `DeterminismFixture` baselines in the same PR, as `game-data-codegen` describes for any content change.

## Risks / Trade-offs

- [Reordering the tiers in a pack changes raw values and breaks saves] → The parity scenario fails on any reorder, the CityPersistence save fixtures decode tiers, and the pack carries a comment that order is save format.
- [A pack removes `peasants` or `merchants`] → The hand-written references stop compiling; the error points at the code that needs them. Not supported (Non-Goals).
- [A pack adds a fourth tier] → It compiles and plays: advancement steps through raw values, sprites fall back to the shared house look, and era gates may name it. Its art and goals are follow-ups. Not covered by a test in this change.
- [Merged need order surprises a pack author] → The order rule is in the spec, and the generated `needs` table shows the result in review.
- [Moving the consumer check breaks inline test fixtures in `GameDataGenTests`] → The fixtures gain the three tiers and use their goods; each fixture that tests something else stays valid.
- [Pack-added needs at 1 per 8 may be poorly balanced] → The rate matches the existing luxuries. Per-good rates are deferred (Open Questions).

## Migration Plan

1. M1: generator support (`Tier` kind, `neededBy`, optional culture tier names, consumer check), the three tiers in `core.yaml`, the parity scenario against the hand-written tables, and the determinism baseline. The emitted Swift does not change yet.
2. M2: emit `HouseTier`, delete the hand-written tables and the CityCore consumer test, generalise consumption and satisfaction (D6), drop Northern European's tier names, and compare the determinism fixtures with the baseline.
Documentation (README contributor section and `FORMAT.md`) lands with M2. Each milestone is its own PR, stacked on the previous one. To roll back M2, revert it: the hand-written tables return and the `Tier` items stay as validated but unused input.

## Open Questions

- Should consumption rates become a per-good or per-tier field? This can be added later without changing the `Tier` or `neededBy` format.
