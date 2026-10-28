## ADDED Requirements

### Requirement: Seasonal events are game data

The game data SHALL hold a catalog of seasonal events as `Event` items, one each for fire, blight, fever and festival. Each item SHALL name its mechanic (`effect`), its possible onset seasons, its earliest age (`minAge`), a weight per difficulty, and the title and text of its banners. The pack validator SHALL reject an event with an unknown effect, an unknown age, no seasons, or a hazard (fire, blight or fever) whose seasons include spring.

#### Scenario: The catalog has four events

- **WHEN** the generated event catalog is read
- **THEN** it holds fire, blight, fever and festival, with fire and blight striking in summer or autumn, fever in autumn or winter, and the festival requested in spring or summer

#### Scenario: A spring hazard is rejected

- **WHEN** a pack declares a fire event with the season spring
- **THEN** pack validation fails and names the item

### Requirement: One seasonal event a year, decided from the seed and the year

On the first tick of each year, with the calendar active and events enabled, the world SHALL decide from its seed and the year alone whether a seasonal event happens that year, which one, and its onset season. The chance and the weights SHALL come from the difficulty, and only events whose `minAge` the player's age has reached SHALL be drawn. No event SHALL be decided before the difficulty's first event year. The decision MUST NOT consume the world's random generator, and MUST use a derivation distinct from the history events'. At most one seasonal event SHALL be warned or under way at a time.

#### Scenario: Same seed, same events

- **WHEN** two worlds with the same seed and difficulty reach the start of the same year
- **THEN** they decide the same seasonal event and onset season, or both none

#### Scenario: No events in the first two years on Normal

- **WHEN** a new Normal game runs from spring 1200 to the end of winter 1201
- **THEN** no seasonal event is warned or started

#### Scenario: The world RNG is untouched

- **WHEN** a year starts and a seasonal event is decided
- **THEN** the world's random generator state is the same as before the decision

#### Scenario: Fever waits for the Medieval age

- **WHEN** the events of 200 years are decided for an Antiquity world on Hard
- **THEN** none of them is fever

### Requirement: Hazards are warned a season ahead

A fire, blight or fever SHALL be warned on the first tick of the season before its onset season, by emitting `seasonalEventWarned` with the event and its onset season. At the warning, the world SHALL check that the event has targets: at least 6 flammable player buildings for fire, at least one operational player crop field for blight, and at least 6 player houses with residents for fever. Without targets, it SHALL NOT warn, and that year SHALL have no seasonal event. A warned hazard SHALL always begin on the first tick of its onset season and emit `seasonalEventStarted`. When it ends it SHALL emit `seasonalEventEnded` with its toll.

#### Scenario: A summer fire is warned in spring

- **WHEN** the event decided for 1202 is a fire in summer and the town has 10 flammable buildings
- **THEN** the tick that starts spring 1202 emits `seasonalEventWarned(fire, summer)`, and the tick that starts summer 1202 emits `seasonalEventStarted(fire)`

#### Scenario: No targets, no warning

- **WHEN** the event decided for a year is a blight and the player has no crop field at the warning
- **THEN** no warning is emitted, and no seasonal event happens that year

### Requirement: Fire starts, spreads and burns down

At a fire's onset, one operational player house or producer SHALL catch fire at a tick derived from the seed and the year in the first half of the onset season, chosen among the candidates in entity-ID order with a derived generator. On Hard, a second one SHALL catch fire in the second half. A burning building SHALL stop producing, collecting tax, growing and taking or giving deliveries. When a fire has burnt for the difficulty's spread time, every flammable building whose footprint touches its own (a gap of 1) and that is not already burning or in ruins SHALL catch fire, in entity-ID order. A building that burns for 300 ticks SHALL become ruins of the same footprint: its stock is lost, its residents leave, and carriers bound for it are redirected as for a demolished building. Flammable buildings SHALL be houses, producers, warehouses, granaries, libraries, fire watches, physicians and herb gardens.

#### Scenario: Fire spreads to a touching house

- **WHEN** a house burns on Normal with no fire watch in reach and another house's footprint touches it
- **THEN** 150 ticks after the first ignition the second house is burning

#### Scenario: A road is a firebreak

- **WHEN** a house burns with no fire watch in reach and the nearest building is across a one-tile road
- **THEN** that building never catches fire from it

#### Scenario: An unanswered fire leaves ruins

- **WHEN** a house with 4 residents and 3 food in its stock burns for 300 ticks
- **THEN** its plot holds ruins of a house, the 4 residents are gone and the food is lost

### Requirement: A fire watch puts out fires in reach

A building that catches fire within 8 tiles (footprint gap) of an operational, road-connected player fire watch SHALL be answered by the nearest idle fire watch, by road path length and then entity ID. Its watchman SHALL walk the road path at one tile a tick and douse the fire for 30 ticks. The fire SHALL be out when he has doused it, and the building SHALL resume with its stock and residents. A fire watch SHALL answer one fire at a time, and further fires in its reach SHALL wait in order of ignition tick, then entity ID. A fire that reaches its spread time or its burn-down time before it is out SHALL spread or burn down as if unanswered.

#### Scenario: A watch saves a house

- **WHEN** a house 10 road tiles from an idle fire watch catches fire on Normal
- **THEN** the fire is out 40 ticks after the ignition, nothing has spread, and the house is operational with its residents

#### Scenario: Out of reach

- **WHEN** a house 9 tiles from the only fire watch catches fire
- **THEN** no watchman is sent

### Requirement: Blight halves crop yields in a marked area

At a blight's warning, the world SHALL pick one operational player crop field with a derived generator, and mark every tile within 6 of its footprint. During the onset season, every player crop field in the marked area SHALL take twice its recipe's cycle ticks, without being marked stalled, including fields built in the area during the blight. A crop field is a building with `crop: true`: the farm, the grain farm and each culture's crop.

#### Scenario: Blighted farm takes twice as long

- **WHEN** a farm in the marked area starts a cycle at the start of a blight season
- **THEN** it completes the cycle after 80 ticks and is never marked stalled

#### Scenario: Farm outside the area

- **WHEN** a farm 7 tiles from the blight's field runs through the blight season
- **THEN** it completes cycles every 40 ticks

### Requirement: Fever holds a district back

At a fever's warning, the world SHALL pick one player house with residents with a derived generator and mark every house within 6 tiles of it. During the onset season, a marked house that is not within 8 tiles of a fuelled player physician SHALL NOT advance a tier. Every leave interval of the difficulty, counted from the onset, up to and including the tick that ends the season, each such house with 2 or more residents SHALL lose one resident. Physicians SHALL burn herbs only while a fever is warned or under way.

#### Scenario: Fever empties a house

- **WHEN** a marked merchant house with 8 residents and no physician in reach goes through a fever season on Normal
- **THEN** it has 5 residents at the end of the season and has not advanced

#### Scenario: A physician spares the house

- **WHEN** a marked house is within 8 tiles of a physician that is fuelled with herbs through the fever season
- **THEN** it loses no residents to fever and can advance

### Requirement: The town asks for a festival

When a festival is decided, on the first tick of its season, the world SHALL issue two linked town orders: bread, and the player culture's luxury. Each SHALL ask for half of what the player made of the good in the last four closed seasons, scaled to one season and clamped to 6–30 bread and 4–20 luxury, capped at 75% of what the player's stores can hold of it. The deadline SHALL be the end of the festival window. The festival SHALL be issued only when the player owns an operational marketplace and made both goods in that window; otherwise that year has no seasonal event. When both orders are fulfilled by the deadline, the festival SHALL run for four seasons. During it, houses within the reach of an operational player marketplace SHALL advance after 60 consecutive ticks of met needs instead of 120, and SHALL pay the difficulty's festival bonus on their tax, rounded down.

#### Scenario: A festival pays more tax

- **WHEN** a festival runs on Normal and a merchant house of 8 residents in reach of the marketplace pays tax
- **THEN** it pays 35 instead of 32

#### Scenario: No marketplace, no festival

- **WHEN** a festival is decided for a year and the player owns no marketplace
- **THEN** no town order is issued and no seasonal event happens that year

#### Scenario: Half a festival is no festival

- **WHEN** the bread order of a festival is fulfilled and the luxury order is not by the deadline
- **THEN** no festival runs, and nothing else changes

### Requirement: Banner text

The seasonal event banners SHALL use this text, with `{season}` the onset season in lower case, `{date}` the end of the event as the HUD shows a date, and `{building}` the burning building's palette name in lower case:

| Event | Banner | Title | Text |
|---|---|---|---|
| fire | warning | Dry {season} ahead | Fire risk is high next season. A fire watch puts out fires within 8 tiles, and a road between buildings stops the flames. |
| fire | each ignition | Fire! | A {building} is burning. Without a fire watch in reach, it spreads to touching buildings and burns down to ruins. |
| fire | end, losses | The fires are out | {count} buildings burnt down. Clear the ruins with Demolish. |
| fire | end, none lost | The fires are out | Nothing was lost. |
| blight | warning | Damp weather: blight is coming | Next season, fields in the marked area yield half. Fill a granary, or buy food at the market. |
| blight | onset | Blight in the fields | Fields in the marked area yield half until {date}. |
| blight | end | The blight has passed | The fields yield in full again. |
| fever | warning | Fever in the harbour towns | Next season it may reach the marked district. A physician with herbs keeps houses within 8 tiles safe. |
| fever | onset | Fever in the town | Houses in the marked district can't advance, and some residents leave, until {date}. |
| fever | end | The fever has passed | {count} residents left the town. |
| festival | request | The town wants a festival | Deliver {bread} bread and {luxury} {luxuryGood} by {date}. Houses near the market then advance faster and pay more tax for a year. |
| festival | held | Festival! | Houses near the market advance faster and pay {bonus}% more tax until {date}. |
| festival | missed | The festival was called off | Nothing was lost. |

The text SHALL live in the event items of the pack, so a change of wording edits data, not Swift.

#### Scenario: Fire warning text

- **WHEN** a fire in summer is warned
- **THEN** the banner title is "Dry summer ahead" and its text is "Fire risk is high next season. A fire watch puts out fires within 8 tiles, and a road between buildings stops the flames."

#### Scenario: Fever end text

- **WHEN** a fever ends after 7 residents left
- **THEN** the banner title is "The fever has passed" and its text is "7 residents left the town."

### Requirement: Chapters schedule events

A chapter SHALL be able to schedule seasonal events by year, onset season and event, and to turn off the random draw with `randomEvents: false`. A scheduled event SHALL replace that year's draw. It SHALL ignore the chance, the weights, the first event year and the minimum target counts, needing one target only, and SHALL be warned like any other event.

#### Scenario: A scheduled fire

- **WHEN** a chapter schedules a fire in summer 1202 with random events off and the town has 2 flammable buildings
- **THEN** a fire is warned at the start of spring 1202, and no other seasonal event happens in any year

### Requirement: Seasonal events are deterministic

Every choice a seasonal event makes SHALL be derived from the seed, the year and a fixed salt per purpose (decision, ignition, area, district), or SHALL follow entity-ID order. All quantities SHALL be integers. Two worlds with the same seed, difficulty and commands SHALL go through the same events with the same outcomes on every platform. A world whose events are disabled SHALL tick exactly as it would without this capability.

#### Scenario: Two runs agree

- **WHEN** two worlds with the same seed and difficulty run the same commands for 12,000 ticks with events on
- **THEN** they are equal at every tick, including burning buildings, ruins, marked areas and counters

#### Scenario: Events off changes nothing

- **WHEN** a world with events disabled runs 12,000 ticks
- **THEN** it is equal to the same world on a build without seasonal events
