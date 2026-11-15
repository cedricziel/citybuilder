## ADDED Requirements

### Requirement: Rivals leave the colony island free
Rivals SHALL be seated on the islands other than home and the colony island, largest first. When fewer such islands hold a town center than the difficulty's rival count, only that many rivals SHALL be seated.

#### Scenario: Rival seats unchanged on the five-island map
- **WHEN** archipelago games with seeds 0 to 9 are created at Hard
- **THEN** three rivals are seated, none on the colony island, on the same islands as the three largest islands other than home

#### Scenario: Too few islands seat fewer rivals
- **WHEN** a Hard archipelago game is generated on terrain with four islands that each hold a town center
- **THEN** two rivals are seated and the colony island stays the player's
