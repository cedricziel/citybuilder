## ADDED Requirements

### Requirement: New Game offers difficulty and scenarios

The New Game dialog SHALL offer a Sandbox mode with a difficulty picker (default Normal) and a Scenario mode listing the built-in scenarios; starting creates the world from the selection.

#### Scenario: Scenario reaches the world

- **WHEN** the player picks Scenario mode, selects The Guild Town and starts
- **THEN** the committed world has The Guild Town's goals and Normal difficulty

#### Scenario: Sandbox difficulty reaches the world

- **WHEN** the player picks Hard in Sandbox mode and starts
- **THEN** the committed world is Hard with no goals

### Requirement: Goals panel and win sheet

In a scenario game the HUD SHALL offer a goals panel listing each goal with its progress, and winning SHALL show a "Scenario complete" sheet.

#### Scenario: Goal progress text

- **WHEN** the goals panel shows "40 residents" with 24 residents in the city
- **THEN** the row reads "Residents 24/40"

#### Scenario: Win sheet appears

- **WHEN** a tick emits `scenarioWon`
- **THEN** the session presents the win sheet
