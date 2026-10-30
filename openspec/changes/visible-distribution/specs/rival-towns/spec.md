## ADDED Requirements

### Requirement: Rivals keep their houses in a market's reach

A rival SHALL place a house only on a plot within a hub's reach: by road, over today's roads plus the ring roads the plot's block would lay, from a road beside one of the rival's hubs, built or being built, to a road beside the plot, at most that hub's radius, as the simulation measures a hub's reach. When a house of the rival with a road is served by no hub, or the town plan has a free house plot but none in reach, the rival SHALL build a marketplace before any other threshold rule, unless one is already being built: on the first free plot in plan order at least half a radius from each of its hubs, and, when a house is unserved, within half a radius of such a house. Rivals follow the same hub, porter, house-stock and radius rules as the player.

#### Scenario: A rival's houses stay near its hubs

- **WHEN** a rival places a house
- **THEN** the house's plot lies within the reach of one of the rival's hubs

#### Scenario: A rival builds a marketplace when its houses would fall outside every hub

- **WHEN** a rival's town plan has free house plots, but none within its town center's reach, and the rival can afford a marketplace
- **THEN** the rival places a marketplace at least 9 tiles from its town center

#### Scenario: A rival whose house no hub serves builds a marketplace near it

- **WHEN** a rival's house with a road lies beyond every hub's reach, and the rival can afford a marketplace
- **THEN** the rival places a marketplace within 9 tiles of that house
