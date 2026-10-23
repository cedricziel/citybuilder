## 1. Change and exploration

- [x] 1.1 In-game before shots of the town and the shore (Mac app, `-uiTestSeedTown`, `-uiTestSeedShore`)
- [x] 1.2 Mock options A, B and C on the compositor and pick one (design "Exploration")
- [x] 1.3 Write proposal, design and spec deltas; `openspec validate terrain-v2 --strict`

## 2. Ground macro field (D1)

- [ ] 2.1 Tests first: the "Ground macro field" scenarios against a pure `GroundMacroField` builder; confirm red
- [ ] 2.2 Implement the builder (vertex colours, noise, water distance, bilinear texels) to green
- [ ] 2.3 Add the multiplyX2 node to `IsoWorldScene`; rebuild on terrain, occupancy or season change only
- [ ] 2.4 In-game before and after (town, shore, winter); PR

## 3. Grass variants and shores (D2, D7)

- [x] 3.1 Tests first: grass variants share their edges; the scene picks grass variants per tile; routing for `-v<n>` grass names
- [x] 3.2 `art.ground` variants; drop the per-tile broad patch; straighter adjacent chords and the shore bands in `art.terrain_tiles`
- [ ] 3.3 Catalog, `TextureFiltering`, `make sprites`, `make sprites-verify`; in-game before and after; PR

## 4. Trees (D3–D6, D9)

- [x] 4.1 Tests first: object selection (densities, occupancy, forest ground is grass; meadow trees dropped), depth order, seasons, routing, byte-stable clumps
- [x] 4.2 `art.flora`; catalog briefs; `make sprites`
- [x] 4.3 `TerrainObjectMap` beside the transition map; object child nodes; season redraw
- [x] 4.4 Node counts and frame times at zoom 0.25 on the archipelago; tighten culling if needed (D9)
- [x] 4.5 Delete `terrain-forest*` ground sprites; in-game before and after (spring, autumn, winter); PR

## 5. Rocks and scree (D3–D6, D8)

- [x] 5.1 Tests first: rock densities and peaks, the scree cover, routing, byte-stable outcrops
- [x] 5.2 `art.rocks`; catalog briefs; `make sprites`
- [x] 5.3 Scree cover node; mountain objects
- [x] 5.4 Delete `terrain-mountain*` ground sprites and the mountain variant count; in-game before and after; PR

## 6. Close

- [ ] 6.1 Update the `iso-sprite-authoring` skill (objects, macro field, compositor) and `world.md`
- [ ] 6.2 `SCENARIO_COVERAGE_STRICT=1 make test-scenarios` for this change's scenarios
