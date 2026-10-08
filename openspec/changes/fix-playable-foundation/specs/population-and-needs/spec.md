## ADDED Requirements

### Requirement: Town center supplies house needs

A road-connected town center SHALL count as a source for house needs in the same way as a road-connected warehouse. A house's food or plank need MUST be reported as satisfied when the town center holds that good and both the house and the town center are road-connected.

#### Scenario: Town center food satisfies a connected house

- **WHEN** a house and the town center are both road-connected and the town center holds food
- **THEN** the house reports its food need as satisfied

#### Scenario: Unconnected town center does not satisfy needs

- **WHEN** the town center holds food but has no adjacent road
- **THEN** a road-connected house with no other food source reports its food need as unmet
