## Context

See proposal.md (Why). `HousePopulation` holds population, per-need satisfaction flags, shortfall flags and a satisfaction streak. `runPopulationSystem` grows or shrinks population against a fixed capacity of 4. Taxes are `totalPop × 1` per interval. The renderer has no per-house state beyond the building record.

## Decisions

### D1 — Tiers are a constant table in CityCore

`HouseTier` (`peasants`, `citizens`, `merchants`, raw values 1–3) exposes `capacity`, `needs: [Good]` and `taxPerResident`. `HousePopulation` gains `tier` and a separate `ticksAtTierCondition` streak for advancement and decline, so growth timing stays as before.

- **Alternative — tiers as different building kinds (house-1, house-2…).** Rejected. Upgrading would mean demolishing and replacing, and every system that counts houses would need to know all kinds.

### D2 — One streak per direction, evaluated every tick

Each tick the house computes `nextTierMet` (full house, all needs of tier + 1 in reach) and `currentTierMet`. While either condition holds, the streak counts up; when it reaches 120 the tier changes and the streak resets. A tick where neither condition holds also resets it. Advancement only ever happens from full capacity, and decline clamps population.

### D3 — Needs are generic over goods

`hasGoodInReach` and the consumption step already take a `Good`, so needs become data: the population system loops over the tier's needs. A `needsSatisfied: [Good: Bool]` map replaces the two hard-coded flags in the data model, while `foodSatisfied`/`planksSatisfied` stay as computed properties for existing callers and saves.

- **Save compatibility:** the decoder reads the old keys when the new map is absent, and `tier` defaults to peasants.

### D4 — Bakery as the minimal tier-3 good

Bread is the cheapest new good that makes merchants reachable: one building, one recipe, input already produced. `deepen-production-chains` later replaces "food" with grain → flour → bread.

### D5 — Tier reaches the renderer through the snapshot

`WorldSnapshot.houseTiers: [EntityID: UInt8]`. `SpriteSpec.building` gains `houseTier: UInt8` (default 1), part of the spec key, so a tier change swaps the node. Texture names: tier 1 keeps `building-house` (and its variants); tiers 2 and 3 use `building-house-tier2` / `-tier3`, constructed by the house stem.

## Determinism

The tier logic is pure integer state updated in the population system's existing order. Tax uses integer per-tier rates. No randomness.

## Risks / Trade-offs

- **[Risk] Peasants no longer consuming planks makes early planks plentiful** → Mitigation: citizens start consuming them quickly, and the citizen tier is where the tax rises.
- **[Trade-off] Bread from generic food** is a placeholder until grain and flour exist.
