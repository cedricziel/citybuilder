## ADDED Requirements

### Requirement: Seasonal events show banners and a chip

Each seasonal event banner (`seasonal-events` / Banner text) SHALL show as a session banner for 60 ticks. From a warning or a festival request until the event ends, the HUD SHALL show an event chip under the date: the event's glyph and "Fire risk · Summer", "Blight · Summer", "Fever · Autumn" or "Festival · by Autumn". Tapping or clicking the chip SHALL show the warning banner again and, for blight and fever, centre the camera on the marked area. On Apple TV the chip SHALL be focusable. The chip SHALL never cover the minimap, the build rail or the first-steps card.

#### Scenario: Warning banner and chip

- **WHEN** a tick emits `seasonalEventWarned(blight, summer)`
- **THEN** the session shows the banner titled "Damp weather: blight is coming" for 60 ticks, and the chip "Blight · Summer" until the blight ends

### Requirement: Ruins inspector

Selecting ruins SHALL show the inspector titled "Ruins of a <kind>", the line "Burnt down in <season year>" and a destructive "Clear ruins — $<cost>" button that runs the demolish command on them.

#### Scenario: Inspecting burnt house ruins

- **WHEN** the player selects the ruins of a house that burnt down in summer 1202
- **THEN** the inspector reads "Ruins of a house", "Burnt down in Summer 1202" and offers "Clear ruins — $15"
