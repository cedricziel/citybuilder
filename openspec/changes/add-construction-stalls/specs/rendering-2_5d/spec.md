## ADDED Requirements

### Requirement: Waiting-for-materials badge

A constructing building in `constructionState == .waitingForMaterials` SHALL render a small overlay badge (e.g. a clock-face icon) anchored to the top-right of its footprint. The badge MUST be hidden when the building is `.actively` constructing or `.operational`. The badge sprite MUST live in `Resources/Buildings.atlas/` as `overlay-waiting-materials.png`, generated procedurally by `scripts/generate-sprites.swift`.

#### Scenario: Waiting building shows the waiting badge

- **WHEN** the renderer reconciles a snapshot containing a building with `state == .constructing` and `constructionState == .waitingForMaterials`
- **THEN** an `overlay-waiting-materials` sprite is attached as a child node of the building tile

#### Scenario: Actively constructing building shows no badge

- **WHEN** the renderer reconciles a snapshot containing a building with `state == .constructing` and `constructionState == .actively`
- **THEN** no waiting badge child node is attached

#### Scenario: Operational building shows no badge

- **WHEN** a building transitions from waiting → actively → operational across ticks
- **THEN** the badge is removed when the building first enters `.actively` and never re-attaches

### Requirement: Ghost preview status tints

The ghost preview's per-good cost row SHALL render each chip in one of three colors based on a `CostStatus` per good:

- `.ok` (have ≥ need) — default foreground color.
- `.queueable` (have < need but producers on the island can supply) — orange or warning color, with a "queue OK" cue in voice/text.
- `.blocked` (have < need and no producer supplies the good on this island) — red.

A cost breakdown with at least one `.blocked` entry MUST mark the overall placement invalid (existing red ghost overlay behavior). A breakdown whose worst status is `.queueable` MUST mark the placement valid (the building queues).

#### Scenario: Cost status is ok when have >= need

- **WHEN** a building's recipe requires 2 wood and the island stockpile has 5 wood
- **THEN** the wood chip's status is `.ok` and renders in the default color

#### Scenario: Cost status is queueable when have < need but producers supply

- **WHEN** the recipe requires 2 wood, the island has 0 wood, but an operational lumberjack hut exists on the island
- **THEN** the wood chip's status is `.queueable` and renders in the warning color

#### Scenario: Cost status is blocked when no path to supply

- **WHEN** the recipe requires 2 planks, the island has 0 planks, and no operational sawmill exists
- **THEN** the planks chip's status is `.blocked` and renders red; the placement is rejected

#### Scenario: Placement allowed when at least one good is queueable and none are blocked

- **WHEN** a breakdown has one `.ok` and one `.queueable` entry
- **THEN** the placement is allowed and the ghost overlay is shown as valid (the building enters `waitingForMaterials` once placed)
