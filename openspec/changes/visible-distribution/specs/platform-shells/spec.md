## ADDED Requirements

### Requirement: Market lines in the inspector

The inspector SHALL show how the market serves a house and how a market hub serves its houses. A house's details and callout SHALL list a line `Stock: ` with each need of its tier as `<good> <units>/<capacity>`, and, when a hub serves it, a line `Market: <hub>, <n> road tiles`. An operational town center or marketplace SHALL list `Serves: <n> houses within <radius> road tiles` and `Porters: <out> of <cap> out`, where the cap is the porters the hub keeps for the houses it serves. These lines SHALL show in the callout as well as the details, and a callout line SHALL wrap at word gaps rather than truncate, so a merchant house's stock of six goods reads in full at phone width.

#### Scenario: A house names its stock and its market

- **WHEN** the player taps a house of 2 peasants 8 road tiles from the town center, holding 2 food
- **THEN** its callout lists "Stock: food 2/2" and "Market: town center, 8 road tiles"

#### Scenario: A house out of reach names no market

- **WHEN** the player taps a house that no market reaches
- **THEN** its callout lists no `Market:` line and names the problem "No market in reach: build a marketplace near it"

#### Scenario: A merchant house's stock reads in full on a phone

- **WHEN** the player taps a merchant house on a phone
- **THEN** its callout shows the whole stock line, wrapped, with every good of the tier

#### Scenario: A town center names its reach and its porters

- **WHEN** the player taps a town center serving 5 houses with 1 porter out
- **THEN** its callout lists "Serves: 5 houses within 18 road tiles" and "Porters: 1 of 2 out"

### Requirement: Distant-house market hint

The first time this session one of the player's houses stands within 4 road tiles of the edge of its market's reach, or out of every market's reach, the session SHALL show a banner titled "Your town is outgrowing its market" saying that porters carry goods only so many road tiles from the town center or a marketplace and that a marketplace near the outer houses serves them, once no other banner shows. When it showed because a house stood out of every market's reach, the building-problem hint SHALL NOT name "No market in reach" again this session; when it showed only for a house near the edge, a house that later falls out of reach SHALL still raise the building-problem hint.

#### Scenario: A house near the edge of the reach raises the hint

- **WHEN** a player house stands 15 road tiles from the town center, whose reach is 18
- **THEN** the banner "Your town is outgrowing its market" shows, once

#### Scenario: A near-edge hint leaves the out-of-reach problem hint

- **WHEN** the hint showed for a house near the edge of the reach, and later a house stands out of every market's reach
- **THEN** the building-problem hint still names "No market in reach"

#### Scenario: Houses close to the market raise no hint

- **WHEN** every player house stands within 10 road tiles of the town center
- **THEN** no market banner shows

#### Scenario: A rival's distant house raises no hint

- **WHEN** only a rival's house stands at the edge of its town center's reach
- **THEN** no market banner shows
