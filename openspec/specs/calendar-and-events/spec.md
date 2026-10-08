# calendar-and-events Specification

## Purpose
TBD - created by archiving change add-calendar-and-events. Update Purpose after archive.
## Requirements
### Requirement: The world has a date

The world SHALL expose a date made of a year and a season, derived from the tick count and a stored start year. A season SHALL last 600 ticks, in the order spring, summer, autumn, winter, and a year SHALL last 2400 ticks. A new game SHALL start in spring 1200 with the calendar active.

#### Scenario: New game starts in spring 1200

- **WHEN** a new game is created
- **THEN** its date is spring 1200 and its calendar is active

#### Scenario: Seasons advance every 600 ticks

- **WHEN** a world with start year 1200 has run 600 ticks
- **THEN** its date is summer 1200

#### Scenario: Year advances every 2400 ticks

- **WHEN** a world with start year 1200 has run 2400 ticks
- **THEN** its date is spring 1201

### Requirement: Season changes are announced

Each tick that starts a new season, after tick 0, SHALL emit a `seasonChanged` world event carrying the new season.

#### Scenario: Season change emits an event

- **WHEN** a world ticks from tick 599 to tick 600
- **THEN** that tick's events include `seasonChanged(summer)`

### Requirement: Winter slows crops

While the calendar is active and the season is winter, farms and grain farms SHALL advance their production cycle at half speed without being marked stalled. Other producers SHALL be unaffected.

#### Scenario: Farm takes twice as long in winter

- **WHEN** an operational farm starts a cycle at the beginning of winter with the calendar active
- **THEN** it completes the cycle after twice its recipe's cycle ticks, and it is never marked stalled

#### Scenario: Sawmill ignores winter

- **WHEN** a supplied sawmill runs through winter with the calendar active
- **THEN** it completes cycles at its normal rate

#### Scenario: Inactive calendar has no winter

- **WHEN** a farm runs through winter with the calendar inactive
- **THEN** it completes cycles at its normal rate

### Requirement: History events at the turn of the year

On each tick that starts a year after the first, with the calendar active, the world SHALL decide from its seed and the year alone whether a history event fires, and which. The world's general random sequence MUST NOT be consumed. The catalog SHALL contain bountiful harvest (up to 8 food into the lowest-ID operational goods buffer), trade caravan (+$150), travelling scholar (+20 knowledge) and rats in the granary (every operational goods buffer loses half its food, rounded down). A fired event SHALL apply immediately and emit a `historyEvent` world event.

#### Scenario: Same seed and year give the same event

- **WHEN** two worlds with the same seed reach the start of the same year
- **THEN** they fire the same history event, or both fire none

#### Scenario: No event in the first year

- **WHEN** a new game runs from tick 0 to tick 2399
- **THEN** no `historyEvent` world event fires

#### Scenario: Trade caravan pays

- **WHEN** a trade caravan event applies
- **THEN** the treasury grows by $150

#### Scenario: Rats halve stored food

- **WHEN** rats in the granary applies to a goods buffer holding 9 food
- **THEN** it holds 5 food afterwards

#### Scenario: Bountiful harvest fills the stores

- **WHEN** a bountiful harvest applies with an operational town center that has free space
- **THEN** the town center holds 8 more food

#### Scenario: Travelling scholar brings knowledge

- **WHEN** a travelling scholar event applies
- **THEN** knowledge grows by 20

#### Scenario: Events leave the world RNG alone

- **WHEN** a year starts and a history event is decided
- **THEN** the world's random generator state is the same as before the decision
