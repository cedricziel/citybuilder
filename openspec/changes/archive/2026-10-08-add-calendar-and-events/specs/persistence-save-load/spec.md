## ADDED Requirements

### Requirement: Saves before the calendar get one

Loading a version-4 save SHALL migrate it to version 5 with an active calendar starting in 1200.

#### Scenario: v4 save loads with a calendar

- **WHEN** a version-4 save is loaded
- **THEN** the world's calendar is active with start year 1200
