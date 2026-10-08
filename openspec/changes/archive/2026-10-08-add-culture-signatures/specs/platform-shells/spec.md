## ADDED Requirements

### Requirement: Culture signature inspector

The inspector SHALL show whether a culture signature building is served and how many buildings, houses or residents it affects. For a caravanserai it SHALL show an export picker listing "None" and every good except coffee in catalog order, the time to the next caravan and what the last caravan sold.

#### Scenario: Picking an export

- **WHEN** the player selects a caravanserai and picks bread in the export picker
- **THEN** a `setExport` command for that caravanserai with bread is enqueued

#### Scenario: Last caravan line

- **WHEN** the last caravan of the selected caravanserai sold 4 bread for $48
- **THEN** the inspector shows "Last caravan: 4 bread for $48"

### Requirement: Out-of-luxury banner

The `fuelRanOut` banner SHALL name the building's fuel good: "<Kind> is out of <good>".

#### Scenario: Forum out of wine

- **WHEN** a tick's events include `fuelRanOut` for a forum
- **THEN** a banner reads "Forum is out of wine"
