## MODIFIED Requirements

### Requirement: History events at the turn of the year

On each tick that starts a year after the first, with the calendar active, the world SHALL decide from its seed and the year alone whether a history event fires, and which. The world's general random sequence MUST NOT be consumed. The catalog SHALL contain bountiful harvest (up to 8 food into the lowest-ID operational goods buffer), trade caravan (+$150), travelling scholar (+20 knowledge) and rats in the granary (every operational goods buffer other than a granary loses half its food, rounded down). A fired event SHALL apply immediately and emit a `historyEvent` world event. When rats in the granary is decided for a year and no operational player goods buffer other than a granary holds at least 2 food, so halving would spoil nothing, no history event SHALL fire that year: the world MUST NOT change and no `historyEvent` world event SHALL be emitted.

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

#### Scenario: Rats skip an empty granary

- **WHEN** a year starts whose decided event is rats in the granary and no operational player goods buffer holds food
- **THEN** that tick emits no `historyEvent` world event and the player's stores are unchanged

#### Scenario: Rats skip a single food

- **WHEN** a year starts whose decided event is rats in the granary and the only operational player goods buffer holds 1 food
- **THEN** that tick emits no `historyEvent` world event and the buffer still holds 1 food

#### Scenario: Rats fire with two food

- **WHEN** a year starts whose decided event is rats in the granary and the only operational player goods buffer holds 2 food
- **THEN** that tick emits the rats `historyEvent` and the buffer holds 1 food

#### Scenario: Bountiful harvest fills the stores

- **WHEN** a bountiful harvest applies with an operational town center that has free space
- **THEN** the town center holds 8 more food

#### Scenario: Bountiful harvest fills only the room for food

- **WHEN** a bountiful harvest applies to a town center holding 35 food and 40 planks
- **THEN** the town center holds 40 food and still 40 planks

#### Scenario: Travelling scholar brings knowledge

- **WHEN** a travelling scholar event applies
- **THEN** knowledge grows by 20

#### Scenario: Events leave the world RNG alone

- **WHEN** a year starts and a history event is decided
- **THEN** the world's random generator state is the same as before the decision

#### Scenario: Rats leave the granary alone

- **WHEN** rats in the granary applies while a warehouse holds 9 food and a granary holds 20 food
- **THEN** the warehouse holds 5 food and the granary still holds 20

#### Scenario: Only the granary holds food

- **WHEN** a year starts whose decided event is rats in the granary and the only food the player has is 30 in a granary
- **THEN** that tick emits no `historyEvent` world event and the granary still holds 30 food
