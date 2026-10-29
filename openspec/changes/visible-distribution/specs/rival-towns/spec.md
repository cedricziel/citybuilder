## ADDED Requirements

### Requirement: Rivals keep their houses in a market's reach

A rival SHALL place a house only on a plot within a hub's reach: the plot's grid distance to one of the rival's hubs, built or being built, plus 2 for the ring road's detour, at most that hub's radius. When the town plan has a free house plot but none in reach, the rival SHALL build a marketplace before any other threshold rule, on the first free plot in plan order at least half a radius from each of its hubs. Rivals follow the same hub, porter, house-stock and radius rules as the player.

#### Scenario: A rival's houses stay near its hubs

- **WHEN** a rival places a house
- **THEN** the house's plot lies within the reach of one of the rival's hubs

#### Scenario: A rival builds a marketplace when its houses would fall outside every hub

- **WHEN** a rival's town plan has free house plots, but none within its town center's reach, and the rival can afford a marketplace
- **THEN** the rival places a marketplace at least 9 tiles from its town center
