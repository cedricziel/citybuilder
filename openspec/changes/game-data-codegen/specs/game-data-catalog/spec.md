## Purpose

Declares the game's content (goods, buildings, production recipes, cultures, techs and ages) in schema-validated YAML content packs. A deterministic generator compiles the packs into the type-safe Swift catalogs the simulation reads.

## ADDED Requirements

### Requirement: Content declared in packs
The system SHALL declare goods, buildings (including production recipes, storage capacity and signature buildings), cultures (including resident names), techs and ages (including rival advancement thresholds) as typed items in YAML pack files. A manifest SHALL list the packs in load order. Each item MUST carry a `kind` (one of `Good`, `Building`, `Culture`, `Tech`, `Age`) and an `id`. The packs MUST be the single source of truth for these values, and they MUST NOT be hand-written in Swift outside the generated output.

#### Scenario: Every catalog entry comes from the packs
- **WHEN** the generator reads the committed manifest and packs
- **THEN** its output defines every good, building kind, recipe, culture, tech and age that the simulation exposes, and no other source defines them

#### Scenario: Schema and decoder agree
- **WHEN** the required and allowed properties of each kind in the published JSON Schema are compared with the keys the generator's decoder requires and accepts
- **THEN** they are equal for every kind

#### Scenario: Unknown field is rejected
- **WHEN** a pack item carries a field its kind does not define
- **THEN** the generator exits with a failure that names the pack, the item and the field

#### Scenario: Shared defaults through anchors and merge keys
- **WHEN** a building item merges an anchored defaults mapping from its own pack with `<<:` and overrides one of its fields
- **THEN** the generated building has the merged defaults and the overridden value

### Requirement: Packs are self-contained
A pack SHALL be able to add a complete feature, such as a culture with its goods, buildings and signature building, without editing any other pack. References MUST point from the item that needs them to the item they name: a building names the tech that unlocks it, and the generator derives each tech's unlock list from those references. References MUST resolve across all packs regardless of load order.

#### Scenario: Adding a culture pack adds the whole culture
- **WHEN** a new pack with a culture, its two luxury goods, its garden, producer and signature building is added to the manifest, and no other file changes
- **THEN** the generated catalogs contain the culture, the goods and the buildings, and the cultivation tech unlocks the new garden and producer

#### Scenario: Reference to a later pack resolves
- **WHEN** a tech in the first pack names an age declared in the last pack
- **THEN** the generator resolves the reference and succeeds

### Requirement: Generator validates the packs
The generator SHALL reject the packs and write no output when any reference cannot be resolved or any invariant is broken. Checks MUST cover: duplicate ids within a kind across all packs, unknown kinds, unknown fields, recipe or material goods that do not exist, unknown buildings, techs, ages or house tiers in references, tech prerequisite cycles, culture luxury chains or signatures that name missing items, pack files that the manifest does not list, manifest entries with no pack file, and inert buildings. Each error MUST name the pack, the item id and the broken reference.

#### Scenario: Unknown good in a recipe is rejected
- **WHEN** a building recipe lists an input good that no pack declares
- **THEN** the generator exits with a failure, names the pack, the building and the unknown good, and writes no files

#### Scenario: Unknown house tier is rejected
- **WHEN** an era tech's gate names a tier that is not `peasants`, `citizens` or `merchants`
- **THEN** the generator exits with a failure that names the tech and the tier

#### Scenario: Tech prerequisite cycle is rejected
- **WHEN** two techs list each other as prerequisites
- **THEN** the generator exits with a failure that names both techs

#### Scenario: Duplicate identifier is rejected
- **WHEN** two packs each declare a building with the same id
- **THEN** the generator exits with a failure that names the id and both packs

#### Scenario: Unlisted pack file is rejected
- **WHEN** a pack file exists in the packs directory but the manifest does not list it
- **THEN** the generator exits with a failure that names the file

### Requirement: Buildings without data behaviour declare a code effect
A building whose behaviour is not described by a recipe that produces goods SHALL declare `effect: code`. This covers houses, storage, roads, the town center, port, shipyard, library, monument and signature buildings. A building with `effect: code` MUST be accepted with or without recipe outputs. A building with neither a recipe that produces goods nor `effect: code` MUST be rejected as inert.

#### Scenario: Inert building is rejected
- **WHEN** a pack declares a building with no recipe and no `effect`
- **THEN** the generator exits with a failure that names the pack and the building

### Requirement: Every good has a consumer
Every good SHALL be consumed somewhere: as a recipe input, a construction material, a culture luxury, or a house tier need.

#### Scenario: Every good has a consumer
- **WHEN** every generated good is looked up among recipe inputs, construction materials, culture luxuries and house tier needs
- **THEN** each good is found in at least one of them

### Requirement: Deterministic generated output
For identical input, the generator SHALL produce byte-identical Swift output on every run and on every supported platform (macOS and Linux). Enum cases MUST appear in load order: packs in manifest order, then items in pack order. That order defines each type's `allCases` order.

#### Scenario: Two runs produce identical output
- **WHEN** the generator runs twice on the same manifest and packs
- **THEN** both runs write byte-identical files

#### Scenario: Case order follows manifest and item order
- **WHEN** the manifest lists pack A before pack B, and each declares two goods
- **THEN** the generated `Good.allCases` lists A's goods in A's order, followed by B's goods in B's order

### Requirement: Saves written before the packs keep loading
Moving content into packs SHALL NOT change any identifier's raw value. A building that was renamed MUST keep its old identifiers as `legacyIds`, and saves that store an old identifier MUST decode to the current building.

#### Scenario: Legacy building identifiers still decode
- **WHEN** a save that stores a building kind as `lumberjack_hut` is decoded
- **THEN** it decodes as the lumberjack hut

### Requirement: Semantic content diff
The generator SHALL compare the content of two revisions and list every changed value as `<Kind> <id>: <field> <old> → <new>`, every added item and every removed item, resolving anchors and merges first. Formatting, comments and key order MUST NOT appear in the diff.

#### Scenario: Value change is listed once
- **WHEN** a building's cost is changed from 120 to 130 and a comment in the same pack is reworded
- **THEN** the diff lists exactly `Building sawmill: cost 120 → 130`

#### Scenario: Anchor change lists every affected item
- **WHEN** an anchor that three buildings merge is changed
- **THEN** the diff lists the changed field once for each of the three buildings

### Requirement: Agent edits are validated at write time
The repository SHALL configure Claude Code hooks so that an agent's edit to a content pack is validated immediately and an agent's hand edit to generated Swift is blocked. Validation errors MUST be returned to the agent with the pack, item and field. Edits to other files MUST pass through without running the generator.

#### Scenario: Invalid pack edit is reported to the agent
- **WHEN** the post-edit hook receives an edit to a pack that now names an unknown good
- **THEN** it exits with status 2 and reports the pack, the item and the unknown good

#### Scenario: Hand edit of generated code is blocked
- **WHEN** the pre-edit hook receives an edit to a file under the generated output directory
- **THEN** it exits with status 2 and tells the agent to edit the pack and regenerate

#### Scenario: Unrelated edit passes through
- **WHEN** either hook receives an edit to a file outside the game-data and generated directories
- **THEN** it exits with status 0 without validating anything

### Requirement: Committed output stays in sync with data
The repository SHALL contain the generated Swift files. A check MUST run in CI and in the pre-commit hook. The check MUST fail when regenerating from the committed manifest and packs would change any committed generated file, or would add or remove one.

#### Scenario: Stale generated output fails the check
- **WHEN** a pack value is edited and the generated files are not regenerated
- **THEN** the sync check fails and names the generated file that would change

#### Scenario: Up-to-date output passes the check
- **WHEN** the generated files were regenerated after the last pack edit
- **THEN** the sync check passes
