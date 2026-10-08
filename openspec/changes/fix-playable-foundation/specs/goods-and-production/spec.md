## ADDED Requirements

### Requirement: Farm produces food

The production catalog SHALL include a recipe for the `farm` building kind with no inputs and an output of 1 `food` every 40 ticks. Food produced by farms MUST flow through the same carrier and warehouse logistics as other goods, so houses can satisfy their food need.

#### Scenario: Farm produces food without inputs

- **WHEN** a farm has been operational for 40 ticks and its output stockpile has room
- **THEN** its output stockpile holds one more food than it did 40 ticks earlier

#### Scenario: Farm food satisfies a connected house

- **WHEN** a farm's food reaches a road-connected warehouse within service range of a house
- **THEN** that house reports its food need as satisfied
