## ADDED Requirements

### Requirement: Multi-frame sprite atlas API
`SpriteAtlas` SHALL expose a single lookup that returns the frame list for any animatable sprite key (terrain idle, building operational, building constructing, walker facing). The lookup MUST return `nil` when any required frame asset is missing so callers can fall back to a static sprite or a colored placeholder.

#### Scenario: Multi-frame water lookup
- **WHEN** the renderer requests frames for `AnimationKey.terrain(.water)` with all four water frame PNGs present
- **THEN** `SpriteAtlas.frames(for:)` returns an array of exactly 4 `SKTexture` values in frame-index order

#### Scenario: Walker lookup routes through the same API
- **WHEN** the renderer requests frames for `AnimationKey.walker(.se)`
- **THEN** the returned array matches what `walkerAnimation(facing: .se)` returns, and both call sites resolve through the same internal `frames(for:)` implementation

#### Scenario: Missing frame returns nil
- **WHEN** any frame PNG for an `AnimationKey` is absent from the bundle
- **THEN** `SpriteAtlas.frames(for: key)` returns `nil` rather than a truncated array

### Requirement: Animation catalog drives cadence
A `SpriteAnimation` catalog in CityRender2D SHALL map every animatable `AnimationKey` to a tunable `(frameCount, timePerFrame, loop)` entry. The catalog MUST be the single source of truth for animation timing; the scene MUST NOT hard-code per-key frame durations.

#### Scenario: Catalog entry exists for each declared animation
- **WHEN** the application starts and any animated terrain or building sprite is rendered
- **THEN** the cadence used by the scene comes from `SpriteAnimation.entry(for:)` and never from a literal in the scene code

#### Scenario: Catalog declares a loop mode per entry
- **WHEN** `SpriteAnimation.entry(for: .terrain(.water))` is queried
- **THEN** its `loop` field is `.forever`, and for `.buildingConstructing(.house)` it is `.progress`

### Requirement: Terrain idle animations
The renderer SHALL play a looped idle animation on every visible tile whose terrain kind has more than one frame defined in the catalog. Tiles whose terrain kind has only one frame MUST render as a static sprite with no animation arming overhead.

#### Scenario: Water tile arms a looped action
- **WHEN** a `terrain(.water)` tile enters the visible range
- **THEN** its `SKSpriteNode` has an `SKAction` running under the key `"anim"` that cycles its texture through the water frame list and never finishes on its own

#### Scenario: Grass tile arms no action
- **WHEN** a `terrain(.grass)` tile enters the visible range
- **THEN** its `SKSpriteNode` has no `SKAction` arming with the key `"anim"`

#### Scenario: Off-screen water stops animating
- **WHEN** a previously-visible water tile leaves the visible range and is removed from the scene by the snapshot reconciler
- **THEN** the node is detached from its parent and no `SKAction` continues to tick for that tile

### Requirement: Operational building animations
Buildings in `BuildingState.operational` whose kind has an operational animation in the catalog SHALL play that animation while visible. Buildings whose kind has no operational animation MUST continue to render as their existing static `building-<kind>.png` sprite.

#### Scenario: Operational sawmill animates
- **WHEN** a sawmill building in `state == .operational` is on screen
- **THEN** its node runs a repeating action that cycles its texture through the sawmill operational frame list

#### Scenario: Operational house is static
- **WHEN** a house building in `state == .operational` is on screen
- **THEN** its node has no animation action attached and renders the single static building sprite

### Requirement: Construction-progress animation
Buildings in `BuildingState.constructing` SHALL render with a scaffold frame derived deterministically from `ticksSincePlacement / buildDurationTicks`. The selected frame MUST be a pure function of these two values and the per-kind frame count; it MUST NOT depend on wall-clock time or RNG.

#### Scenario: Construction frame at start
- **WHEN** a building has just been placed (`ticksSincePlacement == 0`)
- **THEN** its rendered constructing texture is the first frame in the constructing frame list for its kind

#### Scenario: Construction frame at midpoint
- **WHEN** a building's `ticksSincePlacement` equals half its `buildDurationTicks` and the constructing frame list has 3 entries
- **THEN** its rendered texture is the middle frame (index 1)

#### Scenario: Construction frame at completion tick
- **WHEN** a building's `ticksSincePlacement` equals its `buildDurationTicks`
- **THEN** its rendered constructing texture is the last frame in the constructing frame list

#### Scenario: Construction frame is deterministic
- **WHEN** the same `(ticksSincePlacement, buildDurationTicks, frameCount)` triple is fed to the frame-selection function twice
- **THEN** both calls return the same frame index, with no dependency on time, RNG, or scene state

### Requirement: Transition from constructing to operational
When a building's snapshot state transitions from `constructing` to `operational`, the renderer SHALL replace the constructing animation with the operational animation (or with the static operational sprite if no operational animation exists) on the next reconcile, with no stale construction frames remaining on screen.

#### Scenario: Sawmill finishes and starts running
- **WHEN** a sawmill's snapshot state changes from `constructing` to `operational` between two consecutive frames
- **THEN** the next rendered frame shows the operational saw animation and no scaffold overlay

### Requirement: Shared action instances for terrain
Terrain idle animations SHALL share a single `SKAction` instance per terrain kind across all currently-visible tiles of that kind, to bound per-tile allocation cost as the camera pans.

#### Scenario: All visible water tiles share one action reference
- **WHEN** N visible water tiles are present in the scene
- **THEN** each of their `"anim"` actions is identity-equal (`===`) to the same `SKAction` instance returned by the catalog

### Requirement: Fallback to static sprite on missing frames
If the frame list for an `AnimationKey` is unavailable (e.g., missing PNG), the renderer SHALL render the existing static `terrain-<kind>.png` / `building-<kind>.png` sprite without crashing or arming a partial animation. The headless / no-resources fallback to the colored diamond MUST continue to work.

#### Scenario: Missing water frames fall back to static
- **WHEN** the water frame PNGs are not present in the bundle but `terrain-water.png` is
- **THEN** the tile renders as the static water sprite with no `"anim"` action

#### Scenario: No bundle resources at all
- **WHEN** the renderer runs in a context with no bundled sprite resources (e.g., a CityRender2D unit test)
- **THEN** every tile renders as the existing colored-diamond placeholder and no animation is armed

### Requirement: Animation does not influence the simulation
Idle and construction animations SHALL be presentation-only. They MUST NOT mutate `World`, read or write CityCore state, or cause `WorldSnapshot` values to differ between two replays of the same save.

#### Scenario: Replay determinism preserved
- **WHEN** the same save is loaded twice and ticked forward the same number of times in two separate runs
- **THEN** the resulting `World` values are byte-identical, regardless of which animation frames any scene happened to render in between
