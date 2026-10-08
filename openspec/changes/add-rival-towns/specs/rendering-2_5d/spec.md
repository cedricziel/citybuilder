## ADDED Requirements

### Requirement: Buildings render in their owner's culture

Culture variant and age look lookups for a building SHALL use its owner's culture and age: the world's culture and age for player buildings, the rival's for rival buildings. Residents walking on a rival island SHALL take names from the rival's culture.

#### Scenario: Rival town center in its own culture

- **WHEN** the scene draws rival 2's operational town center in a Northern European world where rival 2 is East Asian
- **THEN** the node's texture name is "building-town-center-east-asian"

#### Scenario: Player buildings unchanged

- **WHEN** the scene draws the player's operational town center in the same world
- **THEN** the node uses the shared town center sprite

### Requirement: Rival buildings fly a pennant

Every rival building other than a road, operational or under construction, SHALL carry a pennant child node in its rival's colour, drawn from a texture generated in code (a 1×6 px pole and a 5×3 px triangle), placed at the top-left of the building sprite and above it in z-order. Player buildings SHALL carry no pennant.

#### Scenario: Pennant on a rival house

- **WHEN** the scene draws a house owned by rival 1
- **THEN** the house node has a pennant child in crimson (#B03A2E)

#### Scenario: No pennant on roads or player buildings

- **WHEN** the scene draws a rival road and a player house
- **THEN** neither node has a pennant child
