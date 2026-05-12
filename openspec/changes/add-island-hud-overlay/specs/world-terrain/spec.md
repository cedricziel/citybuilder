## ADDED Requirements

### Requirement: Island name metadata

Every `Island` in the world SHALL carry a `name: String` derived deterministically at world-gen from a seeded pick over a constant 64-entry name table indexed by the island's center tile coordinate and the world seed. The same `(seed, layout)` MUST produce the same set of names assigned to islands in the same order. Names MUST persist across save/load via the existing Codable conformance.

#### Scenario: Island name is deterministic per seed

- **WHEN** two `archipelago` worlds are generated with the same seed
- **THEN** their island lists contain the same names in the same `IslandID` order

#### Scenario: Same name persists across save/load

- **WHEN** a world is saved and loaded
- **THEN** every `Island.name` in the loaded world equals the name at save time

#### Scenario: Different seeds yield different name distributions

- **WHEN** two worlds are generated with different seeds (same `archipelago` layout)
- **THEN** their island-name lists are not element-wise equal (across the 64-entry pool the collision probability is negligible for the 1–8 islands a typical archipelago produces)

#### Scenario: Single-island world has a single name

- **WHEN** a `single-island` world is generated
- **THEN** its one island carries a deterministic name from the same table
