## ADDED Requirements

### Requirement: Difficulty shapes the decline grace

A house's decline grace SHALL be the tier's declared grace plus one on Easy, as declared on Normal, and one fewer on Hard, never below 1.

#### Scenario: Easy waits one interval longer
- **WHEN** the decline grace of a tier declared at 3 is read on Easy, Normal and Hard
- **THEN** it is 4, 3 and 2

#### Scenario: The grace never drops below one
- **WHEN** the decline grace of a tier declared at 1 is read on Hard
- **THEN** it is 1
