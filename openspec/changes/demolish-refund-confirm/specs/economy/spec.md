## ADDED Requirements

### Requirement: Demolishing refunds half the build cost

Demolishing one of the player's standing buildings, finished or still under construction, SHALL credit the player half the building's price, rounded down. Ruins and a burning building SHALL refund nothing: clearing them costs a fee instead. Materials SHALL NOT be refunded.

#### Scenario: Demolishing a building refunds half its cost

- **WHEN** the player demolishes their operational sawmill ($120) and then a house ($50) still under construction, starting from $1,000
- **THEN** the balance is $1,060 after the sawmill and $1,085 after the house

#### Scenario: Ruins and burning buildings refund nothing

- **WHEN** the refund is computed for a house, a road, a burning house and ruins
- **THEN** it is $25, $2, $0 and $0
