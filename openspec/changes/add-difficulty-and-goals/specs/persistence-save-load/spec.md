## ADDED Requirements

### Requirement: Saves before difficulty are Normal sandboxes

Loading a version-7 save SHALL migrate it to version 8 as a Normal sandbox game with no goals.

#### Scenario: v7 save loads as a Normal sandbox

- **WHEN** a version-7 save is loaded
- **THEN** its difficulty is Normal, it has no goals and it is not won
