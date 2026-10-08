## ADDED Requirements

### Requirement: Signature inspector

The inspector SHALL show, for a monument, its stage out of 25 or "Complete: taxes +10%"; for a guild hall, how many workshops it speeds up; for a gallery, a "Commission art ($200)" button, disabled while a commission runs or the balance is below $200, and the time left of a running commission; for a steam engine and a power plant, whether it is fuelled and how many workshops and houses it affects. A house's inspector SHALL note when it is smoky, energised or inspired.

#### Scenario: Commission button

- **WHEN** the player selects a gallery with no commission and a balance of $500, and taps "Commission art ($200)"
- **THEN** a commission command for that gallery is enqueued, and the button is disabled once the commission runs

#### Scenario: Smoky house note

- **WHEN** the player selects a smoky merchant house
- **THEN** the inspector shows "Smoky: −2 residents"

### Requirement: Signature banners

The game SHALL show a banner for `monumentCompleted` ("The monument is complete"), `fuelRanOut` ("<Kind> is out of charcoal") and `commissionEnded` ("The gallery's commission has ended").

#### Scenario: Out of charcoal banner

- **WHEN** a tick's events include `fuelRanOut` for a steam engine
- **THEN** a banner reads "Steam engine is out of charcoal"
