## MODIFIED Requirements

### Requirement: Cross-platform determinism gate
CI SHALL include a determinism job that builds `CityCore` on both macOS and a Linux Swift toolchain, runs a fixed classic archipelago scenario and a generated archipelago at Medium size with 5 islands for 6000 simulation ticks on each, and asserts the post-run `World` Codable JSON is byte-identical between the two runs. The generated world MUST be built by the seeded map generator on each platform, not loaded from a file, so the gate covers map generation as well as ticks.

#### Scenario: Determinism gate blocks PRs on divergence
- **WHEN** a PR changes a function reachable from `World.tick(_:)` in a way that produces different post-tick state on macOS vs Linux for the determinism-scenario fixture
- **THEN** the determinism CI job fails and blocks merge

#### Scenario: Determinism gate passes when math is platform-agnostic
- **WHEN** a PR changes only `Fixed` arithmetic or ship integration code in ways that compute identically on both platforms
- **THEN** the determinism CI job passes

#### Scenario: Determinism gate covers map generation
- **WHEN** a PR changes the seeded map generator in a way that produces different terrain on macOS and Linux
- **THEN** the determinism fixture's generated world differs between the two runs and the determinism CI job fails
