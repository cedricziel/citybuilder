## ADDED Requirements

### Requirement: Terrain directives

A new game SHALL be able to carry an ordered list of terrain directives. World generation SHALL apply them after every town center, starter grove and starter mine site is placed, and before rivals are seated and starter roads are laid. A directive SHALL change only terrain types, SHALL depend only on the layout, the seed and its own parameters, and SHALL NOT draw from the world's random generator. The island list SHALL be unchanged by every directive. A game with no directives SHALL be generated exactly as before this requirement.

The directives are:

- **Thin forest** (island, keep share): on the named island, each forest tile outside the starter grove stays forest only when a hash of the seed and the tile coordinate, taken modulo 100, is below the keep share in percent. Every other forest tile becomes grass.
- **Clear mountains near the town center** (radius): every mountain tile within the given Chebyshev radius of the player's home town center anchor becomes grass. When this removes the starter mine site, the directive SHALL NOT raise a new one.
- **No mountains** (island): every mountain tile on the named island becomes grass.
- **Raise a mine site** (island): the starter mine site rule runs again for the town center on the named island.

"Home" names the island of the player's home town center. Other islands are named by their rank in descending tile count among the islands other than home, ties by lower island ID, so "the second island" is the second largest of them.

#### Scenario: No directives leaves terrain unchanged

- **WHEN** an archipelago game with seed 7 and no directives is created
- **THEN** its terrain is byte-identical to the same game created before terrain directives existed

#### Scenario: Thin forest keeps about the share asked

- **WHEN** an archipelago game is created with seed 3 and the directive "thin forest on home, keep 25%"
- **THEN** the starter grove is whole, every other forest tile on the home island passes the hash rule, and between 20% and 30% of those tiles are still forest

#### Scenario: Thin forest is deterministic

- **WHEN** two games with the same layout, seed and directives are created
- **THEN** their terrain is byte-identical

#### Scenario: Clearing mountains near the town center

- **WHEN** a single-island game is created with the directive "clear mountains within 24 tiles of the town center"
- **THEN** no mountain tile lies within 24 tiles of the player's town center anchor, and mountain tiles farther away are unchanged

#### Scenario: No mountains removes the home mine site

- **WHEN** an archipelago game is created with the directive "no mountains on home"
- **THEN** the home island holds no mountain tile and no mine site

#### Scenario: Raising a mine site on another island

- **WHEN** an archipelago game is created with the directives "no mountains on home" and "raise a mine site on the fourth island"
- **THEN** that island holds a mine site

#### Scenario: Directives leave the island list alone

- **WHEN** an archipelago game with directives is created
- **THEN** its island list has the same IDs, tile counts and bounding boxes as the same game without directives
