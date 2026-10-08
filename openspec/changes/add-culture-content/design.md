## Context

See proposal.md (Why). `HouseTier.needs` is a fixed list per tier and `HousePopulation` keeps one satisfied/shortfall flag pair per need good. `World.culture` and culture sprite lookup exist. Research unlocks buildings via `Tech.unlocks`.

## Decisions

### D1 — Needs depend on culture

`HouseTier.needs(in: Culture)` returns the tier's needs; merchants add `Culture.luxury`. The old `needs` stays as the Northern European list without the luxury for code that has no culture at hand (tests, previews). The population system passes `World.culture`.

### D2 — Satisfaction flags by good

`HousePopulation` replaces the per-good boolean pairs with `satisfied: Set<Good>`-style storage encoded as sorted arrays (`satisfiedGoods`, `shortGoods`), with the tolerant decoder reading the old `foodSatisfied`/`planksSatisfied`/… keys from older saves. `isSatisfied(_:)` keeps its signature.

- **Alternative — a flag pair per luxury.** Rejected: four more pairs today, more with every culture good.

### D3 — Culture luxuries and buildings

`Culture.luxury: Good` and `Culture.luxuryChain: (garden: BuildingKind, producer: BuildingKind)`. `BuildingKind.culture: Culture?` is set for the eight new kinds. `canPlace` rejects a kind of another culture with `.wrongCulture(Culture)` before the tech check. Gardens: 2×2, $60, 2 wood; recipe → 1 raw / 40 ticks. Producers: 2×2, $120, 3 wood + 3 planks; recipe 2 raw → 1 luxury / 50 ticks.

### D4 — Cultivation

`Tech.cultivation` (Medieval, 50, no prerequisites) unlocks all eight culture kinds; the culture rule leaves each player only their own pair. Its `unlocks` list shows all eight; the research panel lists only the world culture's two.

### D5 — UI

The palette hides kinds whose culture differs from the world's (same `isHidden` hook as obsolete kinds). The inspector's needs line uses `needs(in:)`. Good icons follow the existing `good-<raw>` naming.

### D6 — Art

Gardens are field-type sprites (rows of hop poles, vines, tea bushes, coffee shrubs) with a small shed in the culture's style; producers use the culture style from `buildings.py` with a recognisable prop (barrels, wine press, steaming kettle on a veranda, roasting drum). Eight 24×24 good icons.

## Risks / Trade-offs

- **[Risk] Existing merchant houses fall back a tier after the update** because they now need a luxury nobody makes → Accepted: the tier drop is gradual (120 ticks of shortfall) and Cultivation is cheap.
