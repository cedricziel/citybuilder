## ADDED Requirements

### Requirement: List the user's save records

The sync layer SHALL list every save record in the user's private database, returning for each record its game ID, its modification date and its current device. A user with no records MUST get an empty list, not an error. When no iCloud account is signed in, listing MUST fail with a not-signed-in error.

#### Scenario: Listing returns every uploaded game

- **WHEN** saves for games A and B have been uploaded and the sync layer lists the user's records
- **THEN** the list holds exactly one entry for A and one for B, each with the modification date of its latest upload

#### Scenario: Listing with no records is empty

- **WHEN** the user has no save records and the sync layer lists them
- **THEN** the list is empty

#### Scenario: Listing without an account fails

- **WHEN** no iCloud account is signed in and the sync layer lists the user's records
- **THEN** the call fails with the not-signed-in error

### Requirement: Save records round-trip through the private database

A save uploaded through the sync layer SHALL be stored as one record per game in the private database, with the save body as an asset and the uploading device as the current device. Fetching the latest record for that game MUST return a byte-identical body. Uploading again for the same game MUST replace the record, not add a second one.

#### Scenario: Uploaded body fetches back unchanged

- **WHEN** a save body for game G is uploaded and the latest record for G is fetched
- **THEN** the fetched body is byte-identical to the uploaded body and its current device is the uploading device

#### Scenario: Second upload replaces the record

- **WHEN** game G is uploaded twice and the user's records are listed
- **THEN** the list holds one entry for G, dated at the second upload
