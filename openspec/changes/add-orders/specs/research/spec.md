## MODIFIED Requirements

### Requirement: Research cost scales with difficulty

A tech's research cost SHALL be its catalog cost times the difficulty's research percent, rounded down: 80% on Easy, 100% on Normal and 120% on Hard; then, when the player's favour with the crown is at step 1 or 2, less 3% or 5%, rounded down. Research completes when its progress reaches that scaled cost, and the research panel SHALL show the scaled cost.

#### Scenario: Easy research is cheaper

- **WHEN** an Easy world researches Milling
- **THEN** Milling is researched after 448 knowledge points

#### Scenario: Hard research is dearer

- **WHEN** a Hard world researches Milling
- **THEN** Milling is researched after 672 knowledge points and not after 671

#### Scenario: Crown favour makes research cheaper

- **WHEN** a Normal world with crown favour 6 researches Milling, and another with crown favour 12
- **THEN** Milling is researched after 698 knowledge points in the first and after 684 in the second, and not one point sooner
