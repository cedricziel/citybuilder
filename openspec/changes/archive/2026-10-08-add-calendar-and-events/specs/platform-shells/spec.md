## ADDED Requirements

### Requirement: HUD shows the date

The HUD SHALL show the current season and year, such as "Spring 1200".

#### Scenario: HUD date text

- **WHEN** the HUD applies a snapshot dated autumn 1203
- **THEN** its date text is "Autumn 1203"

### Requirement: History events show a banner

When a history event fires, the game screen SHALL show a banner with the event's title and description for 60 ticks.

#### Scenario: Banner appears and expires

- **WHEN** a tick emits a trade caravan history event
- **THEN** the session exposes a banner titled "Trade caravan" for the next 60 ticks, and none after
