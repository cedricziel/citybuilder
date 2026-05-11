## Context

The current sprite layout (`Resources/Sprites/*.png`, loaded via `SKTexture(imageNamed:)`) was a sensible MVP default — minimal moving parts, easy to inspect, no tooling. As the sprite set grows past 50 individual PNGs (animations change adds ~25, archipelago change will add ~50+ more), this approach starts paying real costs: more texture bindings per render frame, sparse packing in GPU memory, slower lookups.

SpriteKit's `.atlas` folder convention is the boring, idiomatic Apple way to fix this. There is no design tension to resolve — the question is sequencing and category factoring. This change is intentionally tiny and surgical.

## Goals / Non-Goals

**Goals**
- Move every existing sprite into one of three category atlases without altering its filename or pixel content.
- Make `SpriteAtlas` consult the atlas layer transparently so callers never need to know which atlas a sprite lives in.
- Establish a normative naming grammar in `sprite-asset-pipeline` that future asset additions follow.
- Fail loudly at startup (debug builds) when a declared sprite is missing from its atlas.

**Non-Goals**
- No new sprites. No new animations. No new building or unit kinds.
- No runtime sprite hot-reload.
- No dynamic atlas generation at runtime.
- No optimization of `SKTextureAtlas` allocation patterns beyond the defaults.

## Decisions

### D1. Three category atlases: Terrain, Buildings, Units

```
   Resources/
     Terrain.atlas/      terrain-{grass,forest,beach,water,mountain}*.png
     Buildings.atlas/    building-*.png
     Units.atlas/        walker-*.png  (ship-*.png arrives in archipelago change)
```

**Why three rather than one mega-atlas:**
- SpriteKit batches draw calls by texture binding. Terrain is drawn in the bottom layer in one pass; buildings in the next; units in the top. Three separate atlases give three predictable draw calls per frame rather than one giant atlas being re-sampled.
- Smaller atlases are friendlier to memory on the iPhone baseline.
- Easier to extend without packing surprises.

**Why not per-kind atlases:**
- Too many tiny atlases reintroduce the texture-binding overhead this change is trying to reduce.

### D2. Filenames unchanged; folders are the only physical move

Every PNG keeps its current filename. Only its directory changes. Migration is a pure `git mv` operation.

**Why:**
- Callers reference sprites by string name. Filename stability means zero call-site churn at name-resolution time.
- Keeps the diff trivially reviewable.

### D3. `SpriteAtlas` is the single point of contact

The existing `SpriteAtlas` type in CityRender2D becomes the *only* place in the codebase that knows about atlases. Its public API (`texture(for:)`, `frames(for:)`, etc.) stays unchanged. Internally it routes lookups by sprite-name prefix:

```
   sprite name prefix    →  atlas name
   ───────────────────      ──────────
   "terrain-..."            "Terrain"
   "building-..."           "Buildings"
   "walker-..."             "Units"
   "ship-..." (future)      "Units"
```

**Why prefix routing rather than per-call atlas argument:**
- Callers should not know nor care which atlas owns a sprite. The naming grammar already encodes the category.
- Routing is a one-line lookup table.

### D4. Asset-presence validation at startup (debug only)

When `SpriteAtlas` is constructed in a debug build, it iterates the catalog of declared sprite names (terrain kinds × frames; building kinds × states × frames; walker facings × frames) and asserts that each resolves to a non-nil texture. In release builds the check is elided — production should never ship with a missing sprite, but if one slips through the renderer can fall back to a single-color placeholder.

**Why debug-only:**
- Startup cost is bounded but non-zero; release builds prefer it elided.
- The check exists to fail tests and dev runs loudly. Production failure mode (placeholder pixel) is preferable to crash.

### D5. Sequencing — land between animations and archipelago

```
   add-terrain-and-building-animations  ────▶  archived
                  │
                  ▼
   add-sprite-atlas-layout              ────▶  this change
                  │
                  ▼
   add-archipelago-and-sea              ────▶  adds new sprites to atlas layout
```

This change MUST follow the animations change because it migrates whatever PNGs exist when it runs. Doing it earlier means animations would need to be rebased onto the new layout mid-flight, which is more disruptive than waiting.

This change MUST precede the archipelago change because the archipelago change extends `sprite-asset-pipeline` (ship and shore-building grammar). Skipping this and rolling atlas migration into archipelago would conflate a pure refactor with substantial new content, inflating PR review surface.

## Risks / Trade-offs

- **Risk:** Xcode atlas compilation occasionally misbehaves on case-sensitive filesystems. Mitigation: pin filenames to lowercase-hyphen-numeric only (already the convention).
- **Risk:** `SKTextureAtlas` returns a placeholder/empty texture for missing names rather than throwing. Mitigation: the debug-build asset-presence check (D4) catches this.
- **Trade-off:** Adds a build-time step (atlas packing) that lengthens clean builds slightly. Acceptable.
