## ADDED Requirements

### Requirement: Workshop speed bonuses shorten cycles

A workshop's extra progress from signature sources SHALL be added only on ticks where it advances, and a cycle SHALL complete when its progress reaches the recipe's cycle length, dropping any surplus. Inputs and outputs per cycle SHALL be unchanged.

#### Scenario: Faster sawmill keeps its recipe

- **WHEN** a sawmill next to a fuelled steam engine completes a cycle
- **THEN** it has used 1 wood and made 1 plank

#### Scenario: Stalled workshop gains nothing

- **WHEN** a sawmill without wood stands next to a fuelled steam engine for 30 ticks
- **THEN** its cycle progress is 0
