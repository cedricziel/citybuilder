## ADDED Requirements

### Requirement: Seasonal event cases

The `WorldEvent` enum SHALL include `seasonalEventWarned(event, onset)`, `seasonalEventStarted(event)`, `seasonalEventEnded(event, toll)`, `buildingCaughtFire(id, kind)`, `fireExtinguished(id)`, `buildingBurntDown(id, kind)`, `ruinsCleared(id)` and `residentLeftWithFever(houseID)`, each carrying the identifiers the audio and the UI need. Adding them MUST NOT change the save format.

#### Scenario: A fire put out

- **WHEN** a fire watch's watchman puts out a fire in a sawmill
- **THEN** that tick's events include `fireExtinguished` with the sawmill's ID
