## ADDED Requirements

### Requirement: Idle-good hint

A good is idle for the player when all of these hold:
- the player's stores together hold at least 20 of it;
- houses don't consume it at any tier of the player's culture;
- the player can build a building that makes goods from it or burns it as fuel (its culture allows it, its research is done, and it isn't obsolete);
- the player owns no building of any kind that uses it.

Projects that make nothing, such as the monument, don't count as using a good.

The first time in a session that a good is idle, the game screen SHALL show a session banner about it, unless another banner is showing. Its title SHALL be "Nothing uses your <good>". Its description SHALL be "Build a <building> for it, or sell <good> at the town center's market." When two or more kinds use it, it SHALL name them as "a <building> or a <building>". Goods are checked in catalog order. The banner SHALL NOT pause the simulation, SHALL show for the usual banner time, and SHALL show at most once per good per session.

#### Scenario: Hops pile up without a brewery

- **WHEN** the player's stores hold 22 hops, cultivation is researched, and the player owns no brewery
- **THEN** the session shows a banner titled "Nothing uses your hops" that names the brewery and the market

#### Scenario: A user in town silences the hint

- **WHEN** the player's stores hold 22 hops and the player owns a brewery under construction
- **THEN** no banner about hops shows

#### Scenario: House goods never count

- **WHEN** the player's stores hold 40 planks and metallurgy is researched, with no toolsmith
- **THEN** no banner about planks shows

#### Scenario: Hint once per good

- **WHEN** the banner about hops has shown, the hops are sold, and hops pile up again in the same session
- **THEN** no second banner about hops shows

#### Scenario: Hint doesn't pause

- **WHEN** the idle-good banner shows
- **THEN** the next step advances the tick
