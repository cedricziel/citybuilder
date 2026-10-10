## Context

See proposal.md for why. `Packages/CityPersistence/Sources/CityPersistence/CloudKitSync.swift` defines `CloudKitClient` (`upload(gameID:body:deviceID:)`, `fetchLatest(gameID:)`, `isAccountAvailable()`), `CloudRecord`, `SyncError`, the last-write-wins `ConflictPolicy`, and the `InMemoryCloudKitClient` actor used by tests. The iOS and Mac entitlements already name the container `iCloud.com.cedricziel.citybuilder`.

## Goals / Non-Goals

**Goals:**

- A production `CloudKitClient` that any platform can use.
- A list call, so a device can discover saves it has no local copy of.
- The `icloud-sync` scenarios run on the host against the fake, and the live client has its own gated tests.

**Non-Goals:**

- Calling the client from any app: sync triggers, conflict prompts, the current-device banner, and the "sync pending" indicator. Those belong to the change that turns sync on.
- Subscriptions or push-driven sync.
- Shared or public databases.

## Decisions

### D1. One record per game, keyed by record name

Record type `CitySave`. The record name is the game ID's UUID string. Fields: `gameID` (String), `body` (CKAsset), `currentDevice` (String). Modification date comes from the record's system field.

- _Alternative: one record per save version._ That keeps history but needs pruning, and last-write-wins only ever needs the newest. Rejected.

Using the game ID as the record name makes upload an upsert (`CKModifyRecordsOperation` with `.allKeys` save policy), so a second upload cannot create a duplicate.

### D2. Listing queries metadata only

`listGames()` runs a query on `CitySave` with `desiredKeys = ["gameID", "currentDevice"]`, so listing never downloads save bodies. It pages with the query cursor until done.

- _Alternative: a zone-change fetch._ Needs a custom zone and change tokens, which is better for incremental sync later but more machinery than a list needs now. Rejected for this change. A custom zone can be added when push sync arrives.

Querying needs the `recordName` field marked queryable in the schema. This is recorded in the schema file and deployed with it.

### D3. Records in the default private zone

- _Alternative: a custom zone._ Needed only for atomic multi-record commits and change tokens. Neither is in scope. Rejected for now. Moving zones later is a migration, noted under Risks.

### D4. Errors map onto `SyncError`

`CKError.notAuthenticated` maps to `.notSignedIn`, and network and service-unavailable errors map to `.offline`. Those are the existing cases. `SyncError` gains one case, `.failed(String)`, for every other CloudKit error, carrying its description. Callers keep matching on `SyncError` only.

### D5. Gated live tests

Live tests run only when `CITYBUILDER_CLOUDKIT_TESTS=1` is set. They use the development environment and a random game ID per run, and delete their records afterwards. CI does not set the variable.

### Determinism

No simulation code changes. The client moves opaque save bodies, and the save format is unchanged.

### CityCore invariant

CloudKit is imported only in CityPersistence. CityCore is untouched and stays framework-free.

## Risks / Trade-offs

- [The schema must be deployed to production before any TestFlight build can sync] → Record the schema in `CityPersistence/CloudKitSchema.md`, and add a deferred task to deploy it in the CloudKit console.
- [Default zone now, custom zone later for push sync] → Records are keyed by game ID, so a later migration can copy them zone to zone. The protocol hides the zone from callers.
- [Live CloudKit behaviour, such as eventual consistency after a write, differs from the fake] → The gated live tests cover upload, fetch and list. List-after-upload in live tests retries briefly before failing.
