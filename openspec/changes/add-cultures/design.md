## Context

See proposal.md (Why). `World` is `Codable` and migrated by numbered steps (current version 5). Building sprites come from the procedural kit in `scripts/generate_sprites_ai/buildings.py`, registered in the sprite catalog and packed into the atlas. The renderer resolves textures by name with a placeholder fallback.

## Decisions

### D1 — `Culture` is a stored enum on `World`

`Culture` (`northernEuropean`, `mediterranean`, `eastAsian`, `middleEastern`) is `Codable` with raw string values in kebab case (`northern-european`, …), a `displayName` and a one-line `blurb`. `World.culture` defaults to Northern European; `World.newGame(layout:seed:culture:)` sets it, and the existing `newGame(layout:seed:)` keeps working with the default. `WorldSnapshot.culture` carries it to the renderer and UI.

- **Alternative — culture as a property of the island.** Rejected for now: rivals will bring other cultures, but the player's city has one culture; the rival change can add per-island culture later.

### D2 — Tier names per culture

`HouseTier.displayName(in: Culture)`:

| Culture | Tier 1 | Tier 2 | Tier 3 |
|---|---|---|---|
| Northern European | Peasants | Citizens | Merchants |
| Mediterranean | Plebeians | Citizens | Patricians |
| East Asian | Farmers | Artisans | Scholars |
| Middle Eastern | Farmers | Craftsmen | Merchants |

The existing `displayName` stays the Northern European name.

### D3 — Culture sprites are suffixed and fall back

Culture variants are named `building-<kind>-<culture>` for the operational look and `building-house-tier<N>-<culture>` for upgraded houses. Construction stages (pad, frame, walls) stay shared. The renderer tries the culture name first and falls back to the shared name, so a culture without a variant still renders. Northern European uses the existing names and has no suffix.

`IsoWorldScene` reads the culture from each snapshot; if it differs from the culture it last drew, it drops every present sprite so the next reconcile rebuilds them.

### D4 — A style table in the building kit

`buildings.py` gains a `Style` dataclass (wall material, roof material, roof shape, rise, eave overhang, timber framing, accent) and a `STYLES` table per culture. The six culture-aware drawers take a `style` argument; Northern European's style reproduces today's pixels exactly, so existing sprites don't change. New primitives: `dome` (a shaded half-ellipse on a drum), `parapet` (a raised rim on a flat roof) and `stacked_roofs` (two or three shrinking hip roofs for the pagoda).

### D5 — Catalog entries

Each variant is a procedural catalog entry beside its base building, registered for `make sprites-procedural` and checked by `make sprites-verify` (content gate included).

### D6 — Migration v5 → v6

Adds `culture: "northern-european"`. `SaveFile.currentVersion` becomes 6; a v5 fixture joins the migration fixtures.

## Risks / Trade-offs

- **[Risk] Mixed looks: culture houses next to shared production buildings** → Mitigation: the shared buildings use neutral timber and stone; `add-culture-content` replaces them with culture buildings.
- **[Risk] 18 new sprites stress the atlas size** → Mitigation: they're small (2×2 and 3×3 footprints); check the atlas budget in `make sprites-verify`.
