## ADDED Requirements

### Requirement: Deficit hint

The first time in a session that the treasury is below zero, the game screen SHALL show the deficit hint as its banner: on the tick that emits `bankruptcyWarning`, or when the session starts with the treasury already below zero and the game not over. On the tick it shows, the hint SHALL take the place of any other banner that tick raises. Its title SHALL be "In the red: upkeep $<upkeep> vs tax $<tax>", with the upkeep and tax of one collection as they stand when it shows. Its description SHALL read "Sell surplus at the town center's market, demolish idle buildings, or build houses before more huts."

While the hint shows, the simulation SHALL be paused without opening the pause menu, so the bankruptcy grace does not run down. The hint SHALL stay until the player dismisses it, with its Resume button, with the pause control or, on the Mac, with Esc; dismissing it resumes the simulation. On Apple TV the Resume button SHALL take focus when the hint shows. The hint SHALL show at most once per session, and the game-over banner SHALL take its place once the game is over.

#### Scenario: Deficit hint names the cause

- **WHEN** a tick emits `bankruptcyWarning` while one collection's upkeep is $14 and its tax is $9
- **THEN** the session shows a banner titled "In the red: upkeep $14 vs tax $9" that names the market, demolishing idle buildings and building houses

#### Scenario: Deficit hint pauses until dismissed

- **WHEN** the deficit hint shows and the session is stepped 100 times
- **THEN** the tick count does not change and the hint still shows, and after the player dismisses it the next step advances the tick

#### Scenario: Deficit hint wins its tick

- **WHEN** a tick emits `bankruptcyWarning` and a history event together
- **THEN** the session shows the deficit hint, not the history event

#### Scenario: Deficit hint on loading a save in the red

- **WHEN** a session starts on a world whose treasury is below zero and whose game is not over
- **THEN** the session shows the deficit hint and is paused

#### Scenario: Deficit hint shows once

- **WHEN** the player dismisses the hint and a later tick emits `bankruptcyWarning` again in the same session
- **THEN** no deficit hint shows
