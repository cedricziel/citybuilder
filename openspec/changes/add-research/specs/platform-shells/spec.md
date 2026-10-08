## ADDED Requirements

### Requirement: Research panel

The HUD SHALL offer a research button that opens a panel listing every tech with its cost, progress, prerequisites, unlocked buildings and state (researched, available, locked). Choosing an available tech MUST issue the choose-research command.

#### Scenario: Research panel lists tech states

- **WHEN** the research panel model is built for a new game
- **THEN** Scholarship is listed as researched, Metallurgy as locked, and Milling, Mining and Seafaring as available

### Requirement: Locked palette entries

Build palette entries for buildings whose tech is not researched SHALL be marked locked, and a locked placement MUST show "Needs <Tech> research".

#### Scenario: Locked placement message

- **WHEN** a placement is rejected with `locked(.mining)`
- **THEN** the HUD message reads "Needs Mining research"
