## ADDED Requirements

### Requirement: Saves before research unlock every tech

Loading a version-3 save SHALL migrate it to version 4 with every tech researched, no current research and zero knowledge, so buildings placed before research existed stay buildable.

#### Scenario: v3 save loads with all techs researched

- **WHEN** a version-3 save is loaded
- **THEN** the world has every tech researched
