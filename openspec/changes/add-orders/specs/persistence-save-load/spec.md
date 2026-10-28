## ADDED Requirements

### Requirement: Saves before orders have none

A save written before orders SHALL load with an empty orders state: no offers, no shipments, no favour and a fulfilled count of 0, at the same save version. If its calendar is active, orders SHALL begin at the next season boundary from the start of its second year. A save with orders SHALL load with its board, shipments, favour and counts as saved.

#### Scenario: A save without orders loads empty

- **WHEN** a save with no orders key is loaded
- **THEN** the world's orders are empty and its other state is as saved

#### Scenario: Orders survive a save and load

- **WHEN** a world with an accepted order, a shipment on the road and favour 4 is saved and loaded
- **THEN** the loaded world is equal to the saved one, and the shipment arrives as it would have
