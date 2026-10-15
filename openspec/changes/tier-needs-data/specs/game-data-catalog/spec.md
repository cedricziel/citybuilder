## MODIFIED Requirements

### Requirement: Content declared in packs
The system SHALL declare goods (including market terms), buildings (including production recipes, storage capacity, planting interval, build-menu category and signature buildings), cultures (including resident names), techs, ages (including rival advancement thresholds) and house tiers (including capacity, tax per resident, needs and display name) as typed items in YAML pack files. A manifest SHALL list the packs in load order. Each item MUST carry a `kind` (one of `Good`, `Building`, `Culture`, `Tech`, `Age`, `Tier`) and an `id`. The packs MUST be the single source of truth for these values, and they MUST NOT be hand-written in Swift outside the generated output.

#### Scenario: Every catalog entry comes from the packs
- **WHEN** the generator reads the committed manifest and packs
- **THEN** its output defines every good, building kind, recipe, culture, tech, age and house tier that the simulation exposes, and no other source defines them

#### Scenario: Schema and decoder agree
- **WHEN** the required and allowed properties of each kind in the published JSON Schema are compared with the keys the generator's decoder requires and accepts
- **THEN** they are equal for every kind

#### Scenario: Unknown field is rejected
- **WHEN** a pack item carries a field its kind does not define
- **THEN** the generator exits with a failure that names the pack, the item and the field

#### Scenario: Shared defaults through anchors and merge keys
- **WHEN** a building item merges an anchored defaults mapping from its own pack with `<<:` and overrides one of its fields
- **THEN** the generated building has the merged defaults and the overridden value

#### Scenario: Tier order is case order
- **WHEN** a pack declares the tiers `peasants`, `citizens` and `merchants` in that order
- **THEN** the generated house tiers list them in that order with the raw values 1, 2 and 3

### Requirement: Generator validates the packs
The generator SHALL reject the packs and write no output when any reference cannot be resolved or any invariant is broken. Checks MUST cover: duplicate ids within a kind across all packs, unknown kinds, unknown fields, recipe, material or need goods that do not exist, unknown buildings, techs, ages or house tiers in references (era gates, culture tier names and `neededBy`), a good listed twice in one tier's needs after merging, tech prerequisite cycles, culture luxury chains or signatures that name missing items, pack files that the manifest does not list, manifest entries with no pack file, inert buildings and goods without a consumer. Each error MUST name the pack, the item id and the broken reference.

#### Scenario: Unknown good in a recipe is rejected
- **WHEN** a building recipe lists an input good that no pack declares
- **THEN** the generator exits with a failure, names the pack, the building and the unknown good, and writes no files

#### Scenario: Unknown house tier is rejected
- **WHEN** an era tech's gate names a tier that no pack declares
- **THEN** the generator exits with a failure that names the tech and the tier

#### Scenario: Unknown tier in neededBy is rejected
- **WHEN** a good declares `neededBy` with a tier that no pack declares
- **THEN** the generator exits with a failure that names the pack, the good and the tier

#### Scenario: Need listed twice is rejected
- **WHEN** a good names a tier in `neededBy` whose `needs` already list that good
- **THEN** the generator exits with a failure that names the good and the tier

#### Scenario: Culture name for an undeclared tier is rejected
- **WHEN** a culture's `tiers` map has a key that names no declared tier
- **THEN** the generator exits with a failure that names the culture and the key

#### Scenario: Tech prerequisite cycle is rejected
- **WHEN** two techs list each other as prerequisites
- **THEN** the generator exits with a failure that names both techs

#### Scenario: Duplicate identifier is rejected
- **WHEN** two packs each declare a building with the same id
- **THEN** the generator exits with a failure that names the id and both packs

#### Scenario: Unlisted pack file is rejected
- **WHEN** a pack file exists in the packs directory but the manifest does not list it
- **THEN** the generator exits with a failure that names the file

### Requirement: Every good has a consumer
Every good SHALL be consumed somewhere: as a recipe input, a construction material, a culture's luxury good, or a house tier need, including needs added with `neededBy`. The generator MUST reject a good that none of these name, and the error MUST name the pack and the good.

#### Scenario: Every good has a consumer
- **WHEN** the generator reads the committed manifest and packs
- **THEN** it finds a consumer for every good and succeeds

#### Scenario: Good without a consumer is rejected
- **WHEN** a pack declares a good that no recipe, material, culture luxury or tier need names
- **THEN** the generator exits with a failure that names the pack and the good

#### Scenario: A tier need is a consumer
- **WHEN** a good is named by no recipe, material or culture luxury, and declares `neededBy` with a declared tier
- **THEN** the generator succeeds

## ADDED Requirements

### Requirement: Packs add needs to existing tiers
A good SHALL be able to add itself to the needs of existing house tiers with `neededBy`, without editing the pack that declares the tier. A tier's needs MUST be its own `needs` in written order, followed by every good that names the tier in `neededBy`, in load order.

#### Scenario: Pack adds a need to an existing tier
- **WHEN** the core pack declares merchants with the needs `food`, `planks`, `bread` and `tools`, and a later pack declares a good `cloth` with `neededBy: [merchants]`
- **THEN** the generated merchants' needs are `food`, `planks`, `bread`, `tools` and `cloth`, and no other tier needs cloth

#### Scenario: Added needs follow load order
- **WHEN** two packs each declare a good with `neededBy: [citizens]`
- **THEN** the generated citizens' needs end with the first pack's good, then the second pack's good

### Requirement: Tier names default per culture
Each house tier SHALL declare a display name. A culture's tier names MUST be optional: a tier the culture leaves out MUST use the tier's own name.

#### Scenario: Culture without tier names uses the tier's names
- **WHEN** a culture declares no `tiers` map
- **THEN** its generated tier names equal the tiers' own names

#### Scenario: Culture overrides one tier name
- **WHEN** a culture's `tiers` map names only `merchants`
- **THEN** its merchants use the culture's name and its other tiers use the tiers' own names
