## MODIFIED Requirements

### Requirement: Rival identity

Each rival SHALL have the name of its island, a colour (rival 1 crimson, rival 2 azure, rival 3 emerald), a culture, a treasury and an age. Rival cultures SHALL be the cultures other than the player's in catalog order. The starting treasury SHALL be $600 on Easy, $1,000 on Normal and $1,400 on Hard. A rival SHALL start in the world's start age and own the town center seeded on its island, with the difficulty's starter stock.

#### Scenario: Rival cultures differ from the player's

- **WHEN** a Northern European archipelago game is created on Hard
- **THEN** rivals 1, 2 and 3 are Mediterranean, East Asian and Middle Eastern

#### Scenario: Rival starting state

- **WHEN** a Medieval archipelago game is created on Hard
- **THEN** rival 1 is named after island 5, is crimson, has $1,400, is in the Medieval age, and the town center on island 5 is owned by rival 1 and holds 4 wood, 4 planks and 1 food
