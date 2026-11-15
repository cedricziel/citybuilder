## ADDED Requirements

### Requirement: Island climate in the status pill
The caption above the island name in the status pill SHALL name the current island's climate: "Temperate island" or "Tropical island" ("Gemäßigte Insel", "Tropische Insel" in German), on the player's islands and on rivals'.

#### Scenario: Pill caption names the climate
- **WHEN** the camera is on a tropical island
- **THEN** the pill's island caption reads "Tropical island"

### Requirement: Island profile in the stocks tray
The stocks tray SHALL show one line under its header describing the current island's profile. For a complete profile it SHALL read "Every crop grows here". Otherwise it SHALL join with " · ": the grain and pasture yields ("Grain 125% · Wool 75%"), whether the player's culture's raw luxury can grow ("Hops: can grow" or "Hops: can't grow"), "Ore" or "No ore", and "Rich forest", "Some forest" or "Sparse forest".

#### Scenario: Tray line on a tropical home
- **WHEN** a Northern European player opens the stocks tray on a home island with grain and pasture at 100%, ore and 12% forest
- **THEN** the tray's profile line reads "Grain 100% · Wool 100% · Hops: can't grow · Ore · Some forest"

#### Scenario: Tray line on a single island
- **WHEN** the player opens the stocks tray in a single-island game
- **THEN** the tray's profile line reads "Every crop grows here"

### Requirement: Soil in the count capsule and inspector
While a crop building's ghost stands where it could be placed, the count capsule SHALL read "Soil N%" with N the yield of its crop family there, neutral at 100% and above and amber below. The inspector of a crop building SHALL show "Soil here: N%".

#### Scenario: Soil capsule on poor ground
- **WHEN** a grain farm ghost could be placed on an island with a grain yield of 75%
- **THEN** the capsule reads "Soil 75%" in the amber tone

#### Scenario: Soil capsule on good ground
- **WHEN** a grain farm ghost could be placed on an island with a grain yield of 125%
- **THEN** the capsule reads "Soil 125%" in the neutral tone

#### Scenario: Inspector shows soil
- **WHEN** the player inspects a farm
- **THEN** the inspector lists "Soil here: 100%"

### Requirement: Climate and ore rejection messages
A placement rejected with `wrongClimate` SHALL show "<building> needs a <climate> island." and one rejected with `noOre` SHALL show "There is no ore under this island.", both in the player's language.

#### Scenario: Hop garden climate message
- **WHEN** a hop garden placement is rejected with `wrongClimate(temperate)`
- **THEN** the HUD message reads "Hop garden needs a temperate island."

#### Scenario: No ore message
- **WHEN** a mine placement is rejected with `noOre`
- **THEN** the HUD message reads "There is no ore under this island."
