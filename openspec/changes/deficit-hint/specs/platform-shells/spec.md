## ADDED Requirements

### Requirement: Deficit hint

The first time in a session that the treasury falls below zero, when the tick emits `bankruptcyWarning`, the game screen SHALL show a banner for 150 ticks. Its title SHALL be "In the red: upkeep $<upkeep> vs tax $<tax>", with the upkeep and tax of one collection as they stand that tick. Its description SHALL read "Sell surplus at the town center's market, demolish idle buildings, or build houses before more huts." The hint SHALL show at most once per session, and the game-over banner SHALL take its place once the game is over.

#### Scenario: Deficit hint names the cause

- **WHEN** a tick emits `bankruptcyWarning` while one collection's upkeep is $14 and its tax is $9
- **THEN** the session shows a banner titled "In the red: upkeep $14 vs tax $9" that names the market, demolishing idle buildings and building houses

#### Scenario: Deficit hint shows once

- **WHEN** the treasury recovers and a later tick emits `bankruptcyWarning` again in the same session
- **THEN** no new deficit banner shows
