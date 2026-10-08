## ADDED Requirements

### Requirement: Terrain sprites fill the iso diamond

Every committed terrain sprite (`terrain-*`) SHALL cover at least 90% of the 64×32 iso diamond mask with opaque pixels (alpha ≥ the pipeline's soft-alpha threshold), and MUST NOT place more than 2% of its opaque pixels outside the diamond. The pipeline SHALL apply a diamond-fit normalisation step to terrain output: scale the opaque bounding box to the diamond's extent, then clip with the diamond mask. Adjacent terrain tiles therefore tile without gaps.

#### Scenario: Every committed terrain sprite fills the diamond

- **WHEN** the content gate inspects every PNG in `Resources/Terrain.atlas/`
- **THEN** each one covers at least 90% of the diamond and has no more than 2% of its opaque pixels outside it

#### Scenario: Content gate rejects an under-filled terrain sprite

- **WHEN** the content gate inspects a committed `terrain-grass.png` that covers 36% of the diamond
- **THEN** the gate fails and names `terrain-grass.png` with reason `terrain_coverage_below_threshold`

### Requirement: Sprite frames are never empty

Every committed sprite PNG in a category atlas SHALL contain at least one opaque pixel. The content gate MUST fail on a fully transparent frame.

#### Scenario: Content gate rejects a fully transparent frame

- **WHEN** the content gate inspects a committed `terrain-water-2.png` with zero opaque pixels
- **THEN** the gate fails and names `terrain-water-2.png` with reason `frame_empty`

### Requirement: Animation frames stay coherent with their base sprite

For every sprite that declares animation frames (`<name>-0` … `<name>-N`) or art variants (`<name>-v1` … `<name>-vN`), each frame and variant SHALL stay visually coherent with the base `<name>.png`. The palette-histogram distance between the frame and the base, computed over 16 quantised luminance-hue bins on opaque pixels, MUST NOT exceed the threshold pinned in `pipeline.toml` (`coherence_max_distance`). The content gate MUST fail on any frame above the threshold.

#### Scenario: Content gate rejects a frame that depicts a different object

- **WHEN** the content gate compares `terrain-water-1.png` (a house) against the `terrain-water.png` base (water)
- **THEN** the gate fails and names `terrain-water-1.png` with reason `frame_incoherent`

#### Scenario: Content gate accepts coherent water frames

- **WHEN** the content gate compares four water frames that differ only in glint placement against their water base
- **THEN** the gate passes for all four frames

### Requirement: Operational frames share one silhouette

Every building operational frame (`<name>-operational-N`) SHALL keep the base sprite's silhouette: the left, right and bottom edges of its opaque bounding box MUST lie within 2 pixels of the base sprite's. The top edge is exempt, so effects such as chimney smoke may rise above the roof. The content gate MUST fail on a frame outside this tolerance with reason `frame_misaligned`. Catalog entries MAY declare `operational = "derived"` to have the pipeline build their operational frames from the base sprite, which satisfies this rule by construction.

#### Scenario: Content gate rejects a shifted operational frame

- **WHEN** the content gate compares `building-sawmill-operational-0.png`, whose building sits 6 pixels left of the base sprite's, against `building-sawmill.png`
- **THEN** the gate fails and names `building-sawmill-operational-0.png` with reason `frame_misaligned`

#### Scenario: Content gate accepts smoke above the roof

- **WHEN** an operational frame matches its base sprite except for smoke pixels drawn above the roof line
- **THEN** the gate reports no `frame_misaligned` failure for that frame

### Requirement: Content gate runs in sprite verification

`make sprites-verify` and the CI sprite job SHALL run the content gate after the byte-identical regen check. The job MUST exit non-zero if any content-gate rule fails, and it MUST print every failing sprite with its reason code, one per line.

#### Scenario: Verification fails on a content defect even when bytes reproduce

- **WHEN** `make sprites-verify` runs against an atlas whose PNGs reproduce byte-for-byte from the cache but where one frame is fully transparent
- **THEN** the command exits non-zero and prints the empty frame's file name with reason `frame_empty`
