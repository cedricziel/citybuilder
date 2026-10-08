## Context

See proposal.md (Why). Commands are queued and applied at tick boundaries; `World` is a `Codable` snapshot, and new fields reach old saves through numbered migrations in CityPersistence (current version 3).

## Decisions

### D1 — `Tech` is a constant table; `ResearchState` lives on `World`

`Tech` (`scholarship`, `milling`, `mining`, `metallurgy`, `seafaring`) exposes `cost`, `prerequisites` and `unlocks: [BuildingKind]`. `World.research: ResearchState { researched: Set<Tech>, current: Tech?, knowledge: Int, progress: Int }`. `Tech.unlocking(kind)` maps a building to its tech (nil means always available).

- **Alternative — knowledge as a stored good.** Rejected: a good needs storage, carriers and capacity, and knowledge isn't physical.

### D2 — Knowledge accrues in a research system each tick

`runResearchSystem` adds 1 per operational library every 10 ticks and 1 per citizen/merchant resident every 100 ticks to `knowledge`. If a tech is current, all knowledge moves into `progress`; reaching the cost marks it researched, clears `current`, and carries the surplus back into `knowledge`.

### D3 — `.chooseResearch(Tech)` command

Validated at apply time: ignored if already researched or prerequisites missing. Choosing replaces the current tech; progress on the replaced tech returns to `knowledge`, so nothing is lost.

### D4 — Tech lock in `canPlace`

After bounds/occupancy, `canPlace` rejects with `.locked(tech)` when the kind's tech isn't researched. Test fixtures (`fixtureWithTerrain`) start with every tech researched, like their unlimited material credits, so existing tests keep their meaning; `newGame` starts with Scholarship only.

### D5 — Migration v3 → v4

Adds `research` with every tech researched, no current, zero knowledge and progress. `SaveFile.currentVersion` becomes 4; a v3 fixture joins the migration fixtures.

## Determinism

Integer counters updated in the system order; commands at tick boundaries; `Set<Tech>` is only queried, never iterated for state changes `researched` is stored as a sorted array, because a `Set` encodes in hash order and would make save bytes differ between runs.

## Risks / Trade-offs

- **[Risk] Locking ports and mills slows the opening** → Mitigation: costs are low (40–60 points ≈ 1–2 minutes with one library).
