## ADDED Requirements

### Requirement: Town center supplies house needs

A road-connected town center SHALL count as a source for house needs in the same way as a road-connected warehouse. A house's food or plank need MUST be reported as satisfied only when a goods buffer holding that good shares a road network with the house: a road path MUST connect a road tile next to the house to a road tile next to the buffer.

#### Scenario: Town center food satisfies a connected house

- **WHEN** a house and the town center are both road-connected and the town center holds food
- **THEN** the house reports its food need as satisfied

#### Scenario: Unconnected town center does not satisfy needs

- **WHEN** the town center holds food but has no adjacent road
- **THEN** a road-connected house with no other food source reports its food need as unmet

#### Scenario: Separate road networks do not share goods

- **WHEN** a house touches one road and the town center, holding food, touches a different road that is not connected to the first
- **THEN** the house reports its food need as unmet

### Requirement: Houses consume food and planks

Every 100 ticks, each operational house with population SHALL consume 1 food per 2 residents (rounded up) and 1 plank, drawn from goods buffers on its road network. Buffers are drained in ascending entity-ID order. When the buffers cannot cover the full amount, the house MUST consume what is available and report that need as unmet until the next consumption succeeds.

#### Scenario: Populated house eats food on the consumption interval

- **WHEN** a house with 4 residents shares a road network with a town center holding 10 food and 10 planks, and the consumption interval elapses
- **THEN** the town center holds 8 food and 9 planks

#### Scenario: Unmet consumption reports the need as unmet

- **WHEN** the consumption interval elapses for a populated house whose only connected buffer holds no food
- **THEN** the house reports its food need as unmet

#### Scenario: Empty house consumes nothing

- **WHEN** the consumption interval elapses for a house with zero residents
- **THEN** no food or planks leave the connected buffers
