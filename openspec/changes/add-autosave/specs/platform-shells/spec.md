## ADDED Requirements

### Requirement: Autosave triggers and feedback
Every shell SHALL request an autosave when the app goes to the background; the Mac SHALL also request one when the app terminates. iPhone, iPad, Mac and Apple TV SHALL all autosave at each season change and after five minutes of play. On Apple TV an autosave SHALL be uploaded to iCloud like a manual save and MUST NOT start a conflict prompt. The pause menu SHALL show "Autosaved <how long ago>" ("Automatisch gespeichert: <vor wie langer Zeit>") once the game has autosaved. A failed autosave SHALL show the session banner "Autosave failed" ("Automatisches Speichern fehlgeschlagen") with the text "Your last save is safe. Save from the pause menu." No new panel or setting is added.

#### Scenario: Pause menu says when
- **WHEN** the game autosaved 20 seconds ago and the pause menu opens
- **THEN** it shows "Autosaved now"

#### Scenario: Failure uses the banner
- **WHEN** an autosave fails
- **THEN** the session banner shows "Autosave failed"

#### Scenario: Apple TV uploads an autosave
- **WHEN** the Apple TV app autosaves
- **THEN** the save is queued for iCloud upload and no conflict is reported

#### Scenario: Quit without saving is honoured
- **WHEN** the Mac player chooses Quit Without Saving
- **THEN** no autosave is written at termination
