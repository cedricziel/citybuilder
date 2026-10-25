## MODIFIED Requirements

### Requirement: Tech tree

The tech catalog SHALL define these techs:

| Tech | Cost | Requires | Unlocks |
|---|---|---|---|
| Scholarship | 30 | — | library |
| Milling | 720 | — | windmill |
| Mining | 720 | — | mine, charcoal burner |
| Metallurgy | 1,440 | Mining | smelter, toolsmith |
| Seafaring | 60 | — | port, shipyard |
| Weaving | 720 | — | sheep farm, weaver |

A new game MUST start with Scholarship researched. Every building kind not listed MUST be available from the start.

#### Scenario: New game starts with Scholarship only

- **WHEN** a new game is created
- **THEN** Scholarship is researched and Milling, Mining, Metallurgy, Seafaring and Weaving are not

#### Scenario: Weaving unlocks the wool chain

- **WHEN** Weaving is researched
- **THEN** the sheep farm and the weaver can be placed, and neither can be placed before
