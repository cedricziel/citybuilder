## MODIFIED Requirements

### Requirement: Climate band metadata
Each `Island` SHALL carry a climate band, `temperate` or `tropical`, derived deterministically at world generation. The default rule SHALL be: an island whose bounding-box centre row lies above the map's middle row is `temperate`, otherwise `tropical`. In an archipelago game the home island and the colony island SHALL instead take the climates given by "Home and colony islands". A single-island game SHALL keep the default rule. The climate value MUST be `Codable` and MUST persist with the world. Climate SHALL decide which culture gardens can grow on an island and SHALL set the grain and pasture yields of its resource profile.

#### Scenario: Every island has a climate
- **WHEN** the island list is queried
- **THEN** every `Island` entry has a non-nil `climate` value drawn from the declared enum

#### Scenario: Climate persists across save/load
- **WHEN** a world is saved and loaded
- **THEN** every island's `climate` value in the loaded world equals the value in the saved world

#### Scenario: Single-island climate keeps the default rule
- **WHEN** a single-island game is created with the Northern European culture and another with the Middle Eastern culture
- **THEN** their islands have the same climate, the one the default rule gives

## ADDED Requirements

### Requirement: Island resource profile
Every `Island` SHALL carry a resource profile, fixed at world generation and persisted with the world: a whole-percent soil yield for each of the crop families field, grain and pasture; whether its gardens grow only in their own climate or every garden grows; whether it has ore; and a forest richness of sparse, fair or rich.

The farm SHALL be the field crop, the grain farm the grain crop, the sheep farm the pasture crop, and the hop garden, vineyard, tea garden and coffee grove the garden crops. The hop garden SHALL need a temperate island; the vineyard, tea garden and coffee grove SHALL need a tropical one. A garden SHALL yield 100% on an island of its climate, or on any island whose profile lets every garden grow, and 0% elsewhere.

In a single-island game the island SHALL get the complete profile: field, grain and pasture 100%, every garden grows, ore present.

In an archipelago game every island other than home SHALL take its climate's yields (temperate: field 100%, grain 125%, pasture 125%; tropical: field 100%, grain 75%, pasture 75%), then add to grain and to pasture a seeded offset of −25, 0 or +25 points each, clamped to 50%–150%. The field yield SHALL be 100% on every island. Ore SHALL be present on the home and colony islands and, on every other island, on a seeded 50% draw. The seeded values SHALL depend only on the seed, the island's ID and the crop family or ore, and SHALL NOT draw from the world's random number generator.

Forest richness SHALL be rich when at least 18% of the island's tiles are forest at world generation, fair when at least 10%, and sparse otherwise. These numbers SHALL be content.

#### Scenario: Single-island profile is complete
- **WHEN** a single-island game is created
- **THEN** its island's profile has field, grain and pasture at 100%, lets every garden grow and has ore

#### Scenario: Profiles are deterministic per seed
- **WHEN** two archipelago games are created with seed 7 and the same culture
- **THEN** every island's profile in the first equals the profile of the island with the same ID in the second

#### Scenario: Field yield is the same everywhere
- **WHEN** archipelago games with seeds 0 to 49 are created for every culture
- **THEN** every island's field yield is 100%

#### Scenario: Soil stays within its range
- **WHEN** archipelago games with seeds 0 to 49 are created
- **THEN** every island other than home has grain and pasture yields between 50% and 150%, in steps of 25 points from its climate's value

#### Scenario: Gardens grow only in their climate
- **WHEN** the yield of a hop garden and of a vineyard is read on a temperate island of an archipelago game
- **THEN** the hop garden yields 100% and the vineyard 0%

#### Scenario: Profiles leave terrain and random draws alone
- **WHEN** an archipelago game is created with seed 3 by this build and its terrain, town centers and random number generator state are compared with a game whose profiles are not assigned
- **THEN** they are identical

#### Scenario: Forest richness follows the forest share
- **WHEN** an island of 200 tiles with 36 forest tiles, one with 20 and one with 19 receive their profiles
- **THEN** they are rich, fair and sparse

### Requirement: Home and colony islands
In an archipelago game the **colony island** SHALL be the smallest island other than home that holds a town center at world generation, ties broken by the lower `IslandID`; there SHALL be none when no such island exists. The player's **luxury climate** SHALL be the climate the player's culture's garden needs. The home island's climate SHALL be the other climate, and the colony island's climate SHALL be the luxury climate. The home island's field, grain and pasture yields SHALL be 100%, its gardens SHALL grow only in its climate, and it SHALL have ore. The colony island SHALL take the yields of its climate with its seeded offsets, and SHALL have ore. Neither choice SHALL depend on the difficulty or on whether rivals are enabled.

#### Scenario: Home cannot grow the player's luxury
- **WHEN** archipelago games with seeds 0 to 49 are created for each of the four cultures
- **THEN** the culture's garden yields 0% on the home island

#### Scenario: The colony can grow the player's luxury
- **WHEN** archipelago games with seeds 0 to 49 are created for each of the four cultures
- **THEN** a colony island exists and the culture's garden yields 100% on it

#### Scenario: Northern European home is tropical
- **WHEN** an archipelago game is created with seed 0 and the Northern European culture
- **THEN** the home island is tropical and the colony island, the smallest island, is temperate

#### Scenario: Home keeps food, grain and pasture
- **WHEN** archipelago games with seeds 0 to 49 are created for each of the four cultures
- **THEN** the home island's field, grain and pasture yields are 100% and it has ore

#### Scenario: Colony does not depend on difficulty
- **WHEN** archipelago games with seed 5 are created at Easy, Normal and Hard
- **THEN** the colony island has the same ID and profile in all three
