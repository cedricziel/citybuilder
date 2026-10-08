## 1. M1 — Anchor fix

- [x] 1.1 Tests-first: translate `#### Scenario: A 2×3 building's sprite sits on its footprint` and `#### Scenario: Square footprints keep their existing anchor` into failing tests in `CityRender2DTests`. Confirm red.
- [x] 1.2 Implement to green: use `w + h − 1` half-tiles for the building and ghost sprite offsets (design D5).
- [x] 1.3 Refactor under a green bar.

## 2. M2 — Gate rules

- [x] 2.1 Tests-first: translate `#### Scenario: Content gate rejects a building without the outline colour` and `#### Scenario: Content gate rejects a floating building` into failing tests in `SpriteContentGateTests`. Confirm red.
- [x] 2.2 Implement to green: add the `outline_missing` and `not_grounded` rules for building base sprites (roads excluded).
- [x] 2.3 Refactor under a green bar.

## 3. M3 — Building kit and redraw

- [x] 3.1 Tests-first (pytest): the projector puts the bottom vertex on the canvas's last row for 2×2, 3×3 and 2×3; every building and unit name is supported; each building has four construction stages; base sprites use the outline colour; canvases match their footprint diamond width.
- [x] 3.2 Implement to green: `Projector`, parts (box, gable and hip roofs, timber frame, openings, chimney, pier, crenellation, shadow), stage handling, and `procedural.size` with integer-factor `render_sheet` (design D1–D4).
- [x] 3.3 Draw house, warehouse, lumberjack hut, sawmill and town center.
- [x] 3.4 Draw port and shipyard in all four orientations.
- [x] 3.5 Draw walkers (4 directions × 2 frames) and ships (8 directions × 2 frames).
- [x] 3.6 Mark every building, walker and ship catalog entry `source = "procedural"`, add the "Building register" section to `world.md`, run `make sprites-procedural`, and check that `make sprites-verify` passes.
- [x] 3.7 Tests-first then green: translate `#### Scenario: Every building and unit entry is procedural`, `#### Scenario: Style bible pins the building register` and `#### Scenario: Committed building sprites pass outline and grounding checks` into tests.
- [ ] 3.8 Runtime check on a dedicated simulator: a town with every building kind (including a port) shows one consistent style, with buildings sitting on their tiles.
- [ ] 3.9 Verify that `make test-scenarios` is clean for this change, then run lint, format and `openspec validate unify-art-style --strict`.
