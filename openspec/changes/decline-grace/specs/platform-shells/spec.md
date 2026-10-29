## ADDED Requirements

### Requirement: The inspector warns of a house about to decline

For a house with a `.runningShort(good, intervals:, grace:)` issue, the inspector's "Problem:" line SHALL read "Short of <good>: residents will leave" during the grace and "Short of <good>: residents are leaving" once the intervals have reached the grace. The text MUST NOT carry a count, so the building-problem banner names it once, not at every interval. Details SHALL list a "Short of <good>:" line with the intervals the need has been short out of the house's grace, never more than the grace.

#### Scenario: Problem text names the coming decline
- **WHEN** the inspector describes `.runningShort(.tools, intervals: 1, grace: 3)` and `.runningShort(.tools, intervals: 3, grace: 3)`
- **THEN** they read "Short of tools: residents will leave" and "Short of tools: residents are leaving"

#### Scenario: Details never counts past the grace
- **WHEN** the player selects a merchant house short of tools for 5 intervals with a grace of 3
- **THEN** its bullets contain "Short of tools: 3 of 3 intervals"

#### Scenario: Details counts the intervals
- **WHEN** the player selects a merchant house short of tools for 2 of its 3 intervals
- **THEN** its bullets contain "Short of tools: 2 of 3 intervals"
