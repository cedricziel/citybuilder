## MODIFIED Requirements

### Requirement: Save location

Saves SHALL be stored one file per game, keyed by a stable game identifier (UUID). On iPhone, iPad and Mac they MUST be stored in the application support directory under a `saves/` subdirectory. On Apple TV, which has no persistent local storage, they MUST be stored in the caches directory under the same `Citybuilder/saves/` subpath, with iCloud as the durable copy (see `icloud-sync`).

#### Scenario: Save path resolution

- **WHEN** the persistence layer resolves the save path for game ID G on iPhone, iPad or Mac
- **THEN** the path is `<ApplicationSupport>/Citybuilder/saves/G.json`

#### Scenario: Apple TV save path resolution

- **WHEN** the persistence layer resolves the save path for game ID G on Apple TV
- **THEN** the path is `<Caches>/Citybuilder/saves/G.json`
