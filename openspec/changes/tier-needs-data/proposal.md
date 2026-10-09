## Why

`game-data-codegen` lets a pack add goods, but not demand for them. What each house tier needs, holds and pays lives in `HouseTier` in Swift. A plausibility run of five generated packs found that three of them added goods nobody consumes: cloth, smoked fish and circuits. Until tier needs are data, every new consumer good needs a Swift change, and packs are not self-contained for anything a population should want.

## What Changes

- Add a `Tier` kind to the packs: `id` (`peasants`, `citizens`, `merchants`), `name`, `capacity`, `taxPerResident`, and `needs` (an ordered list of goods). Tier order follows manifest and item order, as other kinds do (`game-data-codegen` D5).
- Let a pack add needs to an existing tier without editing the pack that declares it: a `Good` can declare `neededBy: [merchants]`. The generator merges these into the tier's need list in load order. This follows the same "reference from the new item to the existing one" rule as `unlockedBy`.
- Generate `HouseTier` cases and their data (`capacity`, `needs`, `taxPerResident`, `displayName`). Advancement, decline, consumption and satisfaction stay in Swift.
- Culture luxuries stay as they are: merchants still add their culture's luxury through `HouseTier.needs(in:)`.
- Tier display names: `game-data-codegen` generates `HouseTier.displayName(in:)` from each culture's `tiers` map, which must name all three tiers. With a `Tier` kind, the tier's `name` becomes the default and a culture's `tiers` map becomes an optional override, so a pack can add a culture without restating names it does not change. The generator rejects a `tiers` key that names no declared tier.
- Move the "every good has a consumer" check from the CityCore test into the generator, now that all consumers are data.
- **BREAKING (balance, opt-in per pack):** a pack that adds a tier need changes advancement for existing saves once it is loaded. The packs shipped in this change keep today's needs exactly, which a parity test checks.

## Capabilities

### New Capabilities
<!-- None. -->

### Modified Capabilities
- `game-data-catalog`: adds the `Tier` kind and `neededBy` on goods, and moves the good-consumer check into the generator.
- `population-and-needs`: tier capacity, needs and taxes are declared in content packs instead of fixed in code. The values do not change.

## Impact

- **Code**: the generated `HouseTier.displayName(in:)` falls back to the tier's `name` when a culture leaves a tier out. `Packages/CityCore/Sources/CityCore/Population.swift` loses its `capacity`, `needs`, `taxPerResident` and `displayName` tables to the generator. Need order feeds consumption and supply, so the generated order must match today's (`food`, `planks`, `bread`, `tools`).
- **Generator**: a new kind, the `neededBy` merge, and the good-consumer check.
- **Depends on**: `game-data-codegen`, through milestone M3 at least.
- **Saves and determinism**: no change for the shipped content. Packs that add needs regenerate the determinism baselines, as `game-data-codegen` describes for any content change.
