## ADDED Requirements

### Requirement: Rival market in the inspector

The inspector on a rival port SHALL show a Market section with "Sells" rows reading "<good> — $<sell price> — <quantity> available" and "Buys" rows reading "<good> — $<buy price> — wants <quantity>". An empty list SHALL read "Nothing for sale" or "Buying nothing".

#### Scenario: Market rows

- **WHEN** the player inspects a rival port whose island holds 42 wood and no tools
- **THEN** the Sells list has the row "Wood — $5 — 12 available" and the Buys list has the row "Tools — $22 — wants 20"

### Requirement: Buy and Sell in the manifest editor

For a rival port, the manifest editor SHALL label load actions "Buy" and unload actions "Sell", and each good row SHALL show the current price and offer quantity, or "no offer" when the rival has none for that good. Rival ports SHALL be selectable during route authoring like player ports.

#### Scenario: Buy label and price

- **WHEN** the player edits the manifest of a rival port that sells 12 wood
- **THEN** the load action reads "Buy" and the wood row shows "$5" and "12"

#### Scenario: Tapping a rival port

- **WHEN** the player taps a rival port while authoring a route
- **THEN** the port is appended to the in-progress waypoints
