## ADDED Requirements

### Requirement: HUD panels animate in and out

The build drawer SHALL slide in from the build rail's side (from the leading edge beside a left rail, from the bottom above a bottom dock) and fade, over 0.3 seconds. The inspector callout SHALL rise 12 points into place and fade in when a building is inspected, and fade out when the inspection ends. The route bar SHALL slide up from the bottom, and history and age banners SHALL slide down from the top. The town market's other goods SHALL fade in and out. Only the opening or closing of a panel and the change of the inspected tile SHALL animate; the panels' changing numbers MUST NOT. With Reduce Motion on, every one of these panels SHALL only fade, over 0.15 seconds, with no movement.

#### Scenario: Build drawer slides from the rail
- **WHEN** the build drawer opens beside a left rail, and above a bottom dock, with Reduce Motion off
- **THEN** it slides from the leading edge, and from the bottom, over 0.3 seconds

#### Scenario: Inspector callout rises into place
- **WHEN** a building is inspected with Reduce Motion off
- **THEN** the callout rises 12 points into place as it fades in

#### Scenario: HUD panels fade under Reduce Motion
- **WHEN** Reduce Motion is on and the build drawer, the inspector callout, the route bar or a banner appears
- **THEN** it only fades, over 0.15 seconds
