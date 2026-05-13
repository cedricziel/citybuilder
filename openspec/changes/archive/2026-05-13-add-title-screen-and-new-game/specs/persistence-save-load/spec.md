## ADDED Requirements

### Requirement: Save metadata query

`CityPersistence.SaveStore` SHALL expose a `mostRecentSave() throws -> SaveMetadata?` query that returns the newest save in the store, or nil when no save exists. The query MUST NOT decode the saved `World`; it operates on file-system metadata only.

A companion `SaveMetadata` type SHALL carry the fields the title screen needs to render the `Continue` row:

- `gameID: UUID` — primary key, matches the existing `SaveStore.url(for:)` convention.
- `writeDate: Date` — file modification date.
- `displayName: String` — caller-formatted label (date in v0; the per-game user label is a follow-up).

#### Scenario: Empty store returns nil
- **WHEN** `mostRecentSave()` is called on a store with no save files
- **THEN** the result is nil

#### Scenario: Single save returns that save
- **WHEN** `mostRecentSave()` is called on a store containing exactly one save
- **THEN** the result wraps that save's `gameID` and write date

#### Scenario: Multiple saves return the newest
- **WHEN** `mostRecentSave()` is called on a store containing three saves with strictly distinct write dates
- **THEN** the result wraps the save with the latest `writeDate`

#### Scenario: Query does not decode world
- **WHEN** `mostRecentSave()` is called on a store whose newest save contains corrupt JSON
- **THEN** the call succeeds and returns the metadata anyway — the corruption surfaces only at load time

### Requirement: Save listing query

`SaveStore` SHALL expose a `listSaves() throws -> [SaveMetadata]` query that returns every save in the store, sorted by `writeDate` descending. The query MUST be a pure file-system scan with no per-save decode.

#### Scenario: Listing reflects sort order
- **WHEN** `listSaves()` is called on a store containing saves with write dates `t0 < t1 < t2`
- **THEN** the result order is `[t2, t1, t0]`

#### Scenario: Empty store returns empty list
- **WHEN** `listSaves()` is called on a store with no saves
- **THEN** the result is the empty array

#### Scenario: Listing tolerates non-save files
- **WHEN** the save directory contains a file whose name does not match the save-file convention
- **THEN** `listSaves()` returns only the matching saves and ignores the foreign file
