## ADDED Requirements

### Requirement: Seasonal events show banners and a chip

Each seasonal event banner (`seasonal-events` / Banner text) SHALL show as a session banner for 60 ticks. From a warning or a festival request until the event ends, the HUD SHALL show an event chip under the date: the event's glyph and "Fire risk · Summer", "Blight · Summer", "Fever · Autumn" or "Festival · by Autumn". Once a fire event has started the chip SHALL read "Fire · 2 burning" while buildings burn and "Fire season · Summer" while none does. Tapping or clicking the chip SHALL show the warning banner again (while a fire burns, the "Fire!" banner of a burning building) and, for blight and fever, centre the camera on the marked area. Where the chip shows only its glyph, its tap target SHALL be at least 44 points square. On Apple TV the chip SHALL be focusable. The chip SHALL never cover the minimap, the build rail or the first-steps card.

Session banners SHALL show one at a time: a banner that arrives while another shows SHALL wait until that one has hidden, a banner equal to one showing or waiting SHALL not show again, and "Fire!" banners SHALL go ahead of the others, a newer one taking the place of one still waiting. Where the HUD's left column is narrower than 240 points, banners SHALL span the HUD above the build controls instead.

#### Scenario: Two banners in one moment

- **WHEN** a fire warning and an age change arrive within a second
- **THEN** the warning shows for 60 ticks, then after a short gap the age change, never both at once

#### Scenario: The chip once the fire burns

- **WHEN** a fire event has started and two farms are burning
- **THEN** the chip reads "Fire · 2 burning"

#### Scenario: Warning banner and chip

- **WHEN** a tick emits `seasonalEventWarned(blight, summer)`
- **THEN** the session shows the banner titled "Damp weather: blight is coming" for 60 ticks, and the chip "Blight · Summer" until the blight ends

### Requirement: New Game offers seasonal events

The New Game dialog SHALL offer "Seasonal events" with the choices On and Off, default On, for sandbox games and the standalone scenarios. Off SHALL start the world with seasonal events disabled. A campaign chapter SHALL never show the option: it runs its schedule, and its random draw follows the chapter's `randomEvents`. A sandbox started on a chapter's map preset SHALL show the option and follow it.

#### Scenario: Events off

- **WHEN** the player starts a sandbox game with "Seasonal events" set to Off and plays to 1210
- **THEN** no seasonal event is warned or started, and history events still fire

#### Scenario: Chapters ignore the toggle

- **WHEN** the player starts Hard Ground 4
- **THEN** the dialog doesn't show the option, and the chapter's scheduled fire is warned in spring 1202

### Requirement: Ruins inspector

Selecting ruins SHALL show the inspector titled "Ruins of a <kind>", the line "Burnt down in <season year>" and a destructive "Clear ruins — $<cost>" button that runs the demolish command on them.

#### Scenario: Inspecting burnt house ruins

- **WHEN** the player selects the ruins of a house that burnt down in summer 1202
- **THEN** the inspector reads "Ruins of a house", "Burnt down in Summer 1202" and offers "Clear ruins — $15"

### Requirement: Fire watch inspector

Selecting a fire watch SHALL show how many of its owner's flammable buildings it would answer ("Covers 3 buildings within 8 tiles by road") and where its watchman is: "Watchman: at the watch", "walking to a fire", "dousing a fire", or "can't leave: no road". Selecting ruins SHALL show "State: ruins".

#### Scenario: A watch with one house on its road

- **WHEN** the player selects a fire watch whose road reaches one house within 8 tiles, with a second house in reach but off its road
- **THEN** the inspector reads "Covers 1 building within 8 tiles by road" and "Watchman: at the watch"
