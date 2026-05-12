## ADDED Requirements

### Requirement: Sprite loading via SpriteAtlas
The 2.5D renderer SHALL obtain every sprite texture used to draw terrain, buildings, walkers, or any future categorized sprite kind exclusively through the `SpriteAtlas` type. Direct calls to `SKTexture(imageNamed:)` for catalogued sprites MUST NOT appear in any CityRender2D source file.

#### Scenario: Renderer source uses SpriteAtlas exclusively
- **WHEN** the CityRender2D test suite runs a code-scan check across all `.swift` files in CityRender2D
- **THEN** no occurrence of `SKTexture(imageNamed:` is found for sprite categories covered by the catalog

#### Scenario: Sprite rendering is unchanged at runtime
- **WHEN** a snapshot is rendered with the post-migration `SpriteAtlas` and compared to a pre-migration screenshot of the same snapshot
- **THEN** the two images are visually indistinguishable (no pixel-level regression check required; visual smoke is sufficient)

### Requirement: Missing-sprite fallback in release
In release builds, if `SpriteAtlas` resolves a sprite name to a nil texture (e.g., due to a catalog bug that escaped debug-build asset-presence checks), the renderer SHALL draw a single-color placeholder sprite (magenta, 32×32) and log the missing sprite name once per process lifetime. The renderer MUST NOT crash.

#### Scenario: Placeholder drawn for missing sprite
- **WHEN** a release build attempts to draw a sprite whose name resolves to nil
- **THEN** a magenta 32×32 placeholder is drawn at the intended position and no crash occurs

#### Scenario: Missing sprite logged once
- **WHEN** the same missing sprite name is encountered N times in a single process lifetime
- **THEN** the renderer logs the name exactly once
