## ADDED Requirements

### Requirement: Saves before island profiles grow everything
A save written before islands had resource profiles SHALL load with the complete profile on every island: field, grain and pasture at 100%, every garden grows, ore present. Each island SHALL keep its stored climate. Such a save SHALL offer no luxury import. The save version SHALL NOT change for this field.

#### Scenario: Old save loads with complete profiles
- **WHEN** the version-12 fixture save is loaded
- **THEN** every island's profile is the complete profile and its climate is the stored one

#### Scenario: Old hop gardens keep growing
- **WHEN** a save written before profiles, holding a hop garden on a tropical island, is loaded and the garden runs 40 ticks outside winter with room for its output
- **THEN** it has produced 1 hops

#### Scenario: Profiles survive save and load
- **WHEN** a new archipelago game is saved and loaded
- **THEN** every island's profile equals its profile before saving
