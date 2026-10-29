## Why

The `icloud-sync` capability describes saves stored in the user's CloudKit private database, but the code only has the `CloudKitClient` protocol and an in-memory fake for tests. Nothing talks to CloudKit, and the protocol cannot list a user's games, so a device with no local copy cannot find its saves. The Apple TV port (`add-tvos-port`) needs both, because tvOS has no persistent local storage. iOS and Mac need them as soon as sync is switched on. Building the client as its own change keeps the riskiest infrastructure separate from the tvOS work and reusable by every platform.

## What Changes

- `CloudKitClient` gains a call that lists every save record in the user's private database, with each record's game ID, modification date and current device. The in-memory fake implements it.
- A production client implements `CloudKitClient` against the private database of `iCloud.com.cedricziel.citybuilder`. It covers the save record type, the body as a `CKAsset`, the `currentDevice` field and account status.
- Live tests against a real container stay behind `CITYBUILDER_CLOUDKIT_TESTS=1`, as the original foundation design (D13) set out. Every other test uses the in-memory fake.
- The CloudKit schema (record type and fields) is written down in the repo and deployed to the production environment.
- Nothing calls the client yet. Turning on sync for iOS and Mac remains its own change, and the tvOS save path is wired in `add-tvos-port`.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `icloud-sync`: adds requirements for listing a user's save records and for a save record round-tripping through the private database. Existing requirements are unchanged.

## Impact

- **CityPersistence**: `CloudKitSync.swift` gets the protocol extension and the fake. A new file holds the production client and imports CloudKit. CloudKit is an Apple framework, so the "Apple frameworks only at runtime" rule holds. CityCore is untouched.
- **Apps**: the iOS and Mac entitlements already declare the CloudKit container, so no change is needed. The tvOS entitlements arrive with `add-tvos-port`.
- **Docs**: a short note in the README on the record schema and how to run the gated live tests.
- **Determinism**: no simulation change.
- **Tooling**: no new build-time tool. Deploying the schema is a one-time step in the CloudKit console.
