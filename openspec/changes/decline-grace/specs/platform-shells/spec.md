## ADDED Requirements

### Requirement: The inspector warns of a house about to decline

For a house with a `.runningShort(good, declining:)` issue, the inspector's "Problem:" line SHALL read "Short of <good>: residents will leave" during the grace and "Short of <good>: residents are leaving" once the house is past it. The text MUST NOT carry a count, so the building-problem banner names it once, not at every interval. Details SHALL list a "Short of <good>:" line with the intervals the need has been short out of the house's grace.

#### Scenario: Problem text names the coming decline
- **WHEN** the inspector describes `.runningShort(.tools, declining: false)` and `.runningShort(.tools, declining: true)`
- **THEN** they read "Short of tools: residents will leave" and "Short of tools: residents are leaving"

#### Scenario: Details counts the intervals
- **WHEN** the player selects a merchant house short of tools for 2 of its 3 intervals
- **THEN** its bullets contain "Short of tools: 2 of 3 intervals"
