## MODIFIED Requirements

### Requirement: The town asks for a festival

When a festival is decided, on the first tick of its season, the world SHALL issue two linked town orders: bread, and the player culture's luxury. Each SHALL ask for half of the player's spare output of the good in the last four closed seasons (`orders` / Order size follows the town's output), scaled to one season and clamped to 6–30 bread and 4–20 luxury, capped at 75% of what the player's stores can hold of it. The deadline SHALL be the end of the festival window. The festival SHALL be issued only when the player owns an operational marketplace and had spare output of both goods in that window; otherwise that year has no seasonal event. When both orders are fulfilled by the deadline, the festival SHALL run for four seasons, the season it is held in included. When either order is declined, lapses or is missed, the festival SHALL be called off at once and the other order closed; goods already delivered stay with the town. During it, houses within the reach of an operational player marketplace SHALL advance after 60 consecutive ticks of met needs instead of 120, and SHALL pay the difficulty's festival bonus on their tax, rounded down.

#### Scenario: A festival pays more tax

- **WHEN** a festival runs on Normal and a merchant house of 8 residents in reach of the marketplace pays tax
- **THEN** it pays 35 instead of 32

#### Scenario: No marketplace, no festival

- **WHEN** a festival is decided for a year and the player owns no marketplace
- **THEN** no town order is issued and no seasonal event happens that year

#### Scenario: Half a festival is no festival

- **WHEN** the bread order of a festival is fulfilled and the luxury order is not by the deadline
- **THEN** no festival runs, and nothing else changes

#### Scenario: Declining a festival order calls it off

- **WHEN** the player declines the luxury order of a festival
- **THEN** the bread order closes too, the "called off" banner shows, and no festival runs
