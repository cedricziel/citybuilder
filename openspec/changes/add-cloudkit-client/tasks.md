## 1. M1 — Listing and round-trip against the fake

- [x] 1.1 Tests-first: translate every scenario in `specs/icloud-sync/spec.md` into failing CityPersistence tests against `InMemoryCloudKitClient`, and confirm red
- [x] 1.2 Implement to green: `icloud-sync` / List the user's save records — add `listGames()` (game ID, modification date, current device) to `CloudKitClient` and `InMemoryCloudKitClient`
- [x] 1.3 Implement to green: `icloud-sync` / Save records round-trip through the private database — the fake keeps one record per game, replaces it on upload and records the uploading device
- [x] 1.4 Refactor under a green bar
- [x] 1.5 Run `SCENARIO_COVERAGE_STRICT=1 make test-scenarios` and confirm that no `icloud-sync` scenario is uncovered

## 2. M2 — Production client

- [x] 2.1 Write `Packages/CityPersistence/CloudKitSchema.md`: record type `CitySave`, its fields, and `recordName` marked queryable (design D1, D2)
- [x] 2.2 Implement the production client's upload (record name = game ID, `CKAsset` body, `currentDevice`, upsert save policy) and fetch-latest, with error mapping to `SyncError` plus its new `.failed` case (design D1, D4)
- [x] 2.3 Implement the production client's `listGames()` (metadata-only query with cursor paging) and account status (design D2)
- [ ] 2.4 Add gated live tests behind `CITYBUILDER_CLOUDKIT_TESTS=1` for upload, fetch, list and replace, which clean up their records (design D5)
- [ ] 2.5 Document the schema and the live-test switch in the README
- [ ] 2.6 Run the gated live tests against the development environment — DEFERRED (requires iCloud account and Apple Developer account)
- [ ] 2.7 Deploy the schema to the production environment in the CloudKit console — DEFERRED (requires Apple Developer account)
