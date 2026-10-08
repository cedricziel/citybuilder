## ADDED Requirements

### Requirement: New Game offers rival towns

In Sandbox mode with the Archipelago layout, the New Game dialog SHALL show a "Rival towns" toggle, on by default, and the committed world SHALL have rivals only when it is on. Selecting the Island Rivalry scenario SHALL set the layout to Archipelago and disable the layout picker.

#### Scenario: Toggle reaches the world

- **WHEN** the player picks Archipelago and Normal, turns "Rival towns" off and starts
- **THEN** the committed world has no rivals

#### Scenario: Island Rivalry locks the layout

- **WHEN** the player picks Scenario mode with Single Island selected and then selects Island Rivalry
- **THEN** the layout is Archipelago and the layout picker is disabled

### Requirement: Standings panel

When the world has rivals, the HUD SHALL offer a standings panel listing each standing row with a colour swatch, name, population, age and wealth, with the player's row in bold. Without rivals the button SHALL be hidden.

#### Scenario: Standings row text

- **WHEN** the panel shows a rival named Ravenshore with 52 residents in the Medieval age and $1,234
- **THEN** its row reads "Ravenshore", "52", "Medieval" and "$1,234"

#### Scenario: Hidden without rivals

- **WHEN** a single-island world is shown
- **THEN** the HUD has no standings button

### Requirement: Rival islands and buildings in the UI

A `foreignIsland` rejection SHALL read "<rival name>'s island — you can't build here." The inspector on a rival building SHALL show the rival's name and colour, use the rival culture's tier names and hide Demolish. When the camera's island belongs to a rival, the island overlay SHALL show "<rival name> (rival)" and hide the stocks row. A `rivalAgeAdvanced` event SHALL show the banner "<rival name> enters the <age>".

#### Scenario: Foreign island text

- **WHEN** a placement on Ravenshore's island is rejected
- **THEN** the banner reads "Ravenshore's island — you can't build here."

#### Scenario: Rival inspector

- **WHEN** the player inspects a peasants' house of a Mediterranean rival
- **THEN** the inspector shows the rival's name, the tier name "Plebeians", and no Demolish button

#### Scenario: Rival island overlay

- **WHEN** the camera centers on Ravenshore's island
- **THEN** the island overlay reads "Ravenshore (rival)" and shows no stocks row

#### Scenario: Rival age banner

- **WHEN** a tick emits `rivalAgeAdvanced` for Ravenshore and the Renaissance
- **THEN** the session shows the banner "Ravenshore enters the Renaissance"
