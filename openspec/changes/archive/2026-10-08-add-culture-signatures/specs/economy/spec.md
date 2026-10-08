## ADDED Requirements

### Requirement: Forum bonus counts as tax

The forum's extra tax SHALL be part of the owner's house tax: it SHALL be reported in `taxesCollected` and SHALL be raised by a completed monument's bonus like the rest of the tax.

#### Scenario: Forum and monument

- **WHEN** one tax interval passes with a completed monument and a single merchant house of 8 residents within 8 tiles of a served forum
- **THEN** the tax collected is 52

### Requirement: Caravan income

Caravan revenue SHALL be credited to the caravanserai owner's balance when the caravan leaves, outside the tax and upkeep intervals' figures.

#### Scenario: Caravan income is not tax

- **WHEN** on Normal, with an unserved caravanserai as the only building and no houses, a caravan sells 4 bread on a tick that is also a tax and upkeep interval
- **THEN** the balance rises by 46 (48 revenue minus 2 upkeep) and no `taxesCollected` event is emitted
