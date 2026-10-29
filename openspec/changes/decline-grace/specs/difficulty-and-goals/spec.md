## ADDED Requirements

### Requirement: Difficulty shapes the decline grace

A house's decline grace SHALL be the tier's declared grace plus one on Easy, as declared on Normal, and one fewer on Hard, never below 1. A tier declared at 1 SHALL wait 1 interval on every difficulty.

#### Scenario: Easy waits one interval longer
- **WHEN** the decline grace of a tier declared at 3 is read on Easy, Normal and Hard
- **THEN** it is 4, 3 and 2

#### Scenario: A tier declared at one never waits longer
- **WHEN** the decline grace of a tier declared at 1 is read on Easy, Normal and Hard
- **THEN** it is 1, 1 and 1

#### Scenario: The grace never drops below one
- **WHEN** the decline grace of a tier declared at 2 is read on Hard
- **THEN** it is 1
