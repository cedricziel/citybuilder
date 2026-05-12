## Why

The renderer currently loads every sprite as an individual `SKTexture(imageNamed:)` lookup against the main bundle. Today that means ~30 PNGs in `Resources/Sprites/`; with `add-terrain-and-building-animations` landing that climbs to ~55 PNGs; with `add-archipelago-and-sea` it would climb past 100. Each lookup is a separate GPU texture and a separate state change when batching draws.

SpriteKit ships a first-class atlas mechanism — the `.atlas` folder convention — that packs many PNGs into a single GPU texture at app build time without changing the authoring workflow. You keep generating individual PNGs from `scripts/generate-sprites.swift`; Xcode packs them; the runtime queries by sprite name via `SKTextureAtlas`. This is almost pure upside (fewer draw-call state changes, tighter memory packing, faster lookups) and the migration is mechanical.

This change does that migration as a standalone refactor — no behavior change, no new sprite content, no new gameplay. Its sole purpose is to put the asset pipeline on the layout that subsequent gameplay changes (notably `add-archipelago-and-sea`) can extend without fighting the structure.

## What Changes

- Reorganize `Resources/Sprites/` into three category atlases under `Resources/`:
  - `Terrain.atlas/` — all `terrain-*` PNGs
  - `Buildings.atlas/` — all `building-*` PNGs
  - `Units.atlas/` — all `walker-*` PNGs
- Update `scripts/generate-sprites.swift` so each sprite-generation function writes its PNG to the appropriate atlas folder rather than a flat `Resources/Sprites/`.
- Update the `SpriteAtlas` type in CityRender2D to resolve sprite names by consulting the appropriate `SKTextureAtlas` (named after the category) rather than `SKTexture(imageNamed:)`. The public API of `SpriteAtlas` stays unchanged; only the implementation moves.
- Update `project.yml` to reference the three atlas folders as bundle resources, replacing the old `Resources/Sprites/` path.
- Add an asset-presence check that runs at SpriteAtlas initialization (in debug builds): fail fast and log if any sprite declared in the catalogs cannot be resolved.
- Migrate the in-flight animations change's PNGs to the new layout at archive time (mechanical move; no content change).
- Document the sprite naming grammar (current kinds only) in a new `sprite-asset-pipeline` capability spec so future changes that add sprites have a single normative reference.

## Capabilities

### New Capabilities

- `sprite-asset-pipeline`: Atlas folder convention, sprite naming grammar (for currently-known sprite kinds), `SpriteAtlas` API contract over `SKTextureAtlas`, asset-presence validation at startup.

### Modified Capabilities

- `rendering-2_5d`: route sprite loading through the new `sprite-asset-pipeline` rather than direct `imageNamed:` lookups. Rendering semantics are otherwise unchanged.

## Impact

- **No behavior change.** Same pixels on screen, same animation cadence, same culling, same scene tree. This change is a refactor of how sprites are organized on disk and how they get into GPU memory.
- **Build-time overhead**: clean builds gain a few seconds for atlas compilation. Incremental builds essentially unchanged.
- **GPU behavior**: fewer texture bindings per render frame — beneficial when many sprites of the same category are on-screen (most frames).
- **Memory**: atlases pack into power-of-two textures; small individual PNGs that previously left whitespace in their own texture pages are now densely packed.
- **Git diff**: PNG file moves are git-renames; content is unchanged. No `.atlasc` (compiled binary atlas) is checked in — Xcode generates it into DerivedData at build time.
- **No third-party tooling.** `SKTextureAtlas` is built into SpriteKit; the `.atlas` folder convention is Xcode-native.
- **Sequencing**: this change MUST land after `add-terrain-and-building-animations` archives, so the migration moves a known stable set of PNGs. It MUST land before `add-archipelago-and-sea` begins implementation, since the archipelago change adds sprites (ship, port, shipyard) under the new layout.

## Dependencies

- **Requires (must precede this change):** `add-terrain-and-building-animations` to be archived. That change is the last one expected to add PNGs under the old flat `Resources/Sprites/` layout; once it archives, the full set of legacy sprites is known and stable, and this migration becomes deterministic.
- **Blocks (must precede those changes):** `add-archipelago-and-sea`. The archipelago change extends `sprite-asset-pipeline` (ship and shore-building grammar) and expects atlases to exist.
