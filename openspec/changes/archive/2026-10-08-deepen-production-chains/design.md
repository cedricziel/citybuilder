## Context

See proposal.md (Why). Production, carriers and supply are generic over `ProductionRecipe` inputs and outputs, so new chains are mostly data. Producers with inputs already get buffer→producer carriers (one good at a time, topped up to twice the recipe amount), and a cycle only advances when every input is present.

## Decisions

### D1 — Chains are catalog data

Each new building is a `BuildingSpec` plus a `ProductionRecipe`; no new systems. Supply carriers already handle multiple inputs per producer, because they loop over the recipe's goods.

### D2 — Terrain requirement on the building spec

`BuildingSpec` gains `requiredTerrain: (TerrainType, minTiles)?`. `canPlace` counts footprint tiles of that terrain after the occupancy checks and rejects with `PlacementRejection.needsTerrain(TerrainType)`. Only the mine uses it.

- **Alternative — a mountain-only "mine" tile type.** Rejected. A footprint threshold lets mines sit on the mountain's edge, next to roads on grass.

### D3 — Merchants gain tools; grain does not replace food

Food stays the everyday need for all tiers so the opening loop (farm → houses) is unchanged. Bread moves to flour, and tools give merchants a need served by the deepest chain. Consumption: 1 tool per 8 residents.

### D4 — Needs stay per-good flags

`HousePopulation` adds a tools flag pair alongside the food, planks and bread flags, behind the same accessors.

## Determinism

Recipes are integer constants processed in the existing order; supply and consumption already iterate in entity-ID order.

## Risks / Trade-offs

- **[Risk] Supply carriers per producer are capped at 2 in flight**, which can starve two-input producers far from storage → Mitigation: the cap counts per producer, and short paths keep throughput adequate; revisit with warehouse range later.
