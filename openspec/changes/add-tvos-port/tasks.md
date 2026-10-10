## 1. M1 — tvOS target that builds and launches

- [ ] 1.1 Tests-first: translate `platform-shells` scenarios "Universal Purchase one buy" and "App targets share one bundle identifier" into failing swift-testing tests (parse `project.yml` from the test) and confirm red
- [ ] 1.2 Add `.tvOS(.v18)` to the platforms of all six packages; run `swift test` for each package on the host and `scripts/check-no-apple-ui-imports.sh` to confirm CityCore is unchanged
- [ ] 1.3 Narrow touch-location and gesture-recogniser guards from `canImport(UIKit)` to `os(iOS)` in `IsoWorldScene.swift` and `IsoWorldScene+LongPress.swift` (design D6); keep image and colour loading on `canImport(UIKit)`
- [ ] 1.4 Compile out `keyboardShortcut`, `Stepper`, `Slider` and Handoff advertising on tvOS behind `#if !os(tvOS)` placeholders so CityUI and CityAudio build for `generic/platform=tvOS Simulator`
- [ ] 1.5 Implement to green: `platform-shells` / Universal Apple platform support — add the `CitybuilderTV` target and scheme to `project.yml` (tvOS 18, shared bundle id, the same resource atlases and audio, iCloud entitlements), and add `Apps/CitybuilderTV/` with the app entry, Info.plist (`ITSAppUsesNonExemptEncryption: false`) and entitlements
- [ ] 1.6 Extend `scripts/generate-app-icon.swift` to write the layered tvOS App Icon (small and large image stacks, opaque layers) and a static Top Shelf image (wide and standard) into `Apps/CitybuilderTV/Assets.xcassets`
- [ ] 1.7 `make generate`, then build `CitybuilderTV` for the tvOS simulator and launch to the title screen with the verify skill
- [ ] 1.8 Refactor under a green bar
- [ ] 1.9 Verify `make test-scenarios` is clean for `platform-shells`

## 2. M2 — Remote and controller input

- [ ] 2.1 Tests-first: translate every `tv-remote-controls` scenario and the `rendering-2_5d` scenario "Remote select dispatched as a tap on the reticle tile" into failing CityUI tests against a platform-neutral `RemoteInputMapper` (design D5) and confirm red
- [ ] 2.2 Implement to green: `tv-remote-controls` / Reticle marks the target tile — reticle tile from `Camera.centerTile()`, hovered tile and tooltip delay driven by the reticle
- [ ] 2.3 Implement to green: `tv-remote-controls` / Remote pans the map — zoom-scaled swipe pan through `handlePanDelta`, directional clicks as `IsoDirection` camera steps (design D2), clamped to the map bounds
- [ ] 2.4 Implement to green: `tv-remote-controls` / Zoom without pinch — zoom step buttons and trigger zoom within the existing bounds
- [ ] 2.5 Implement to green: `tv-remote-controls` / Select and press-and-hold on the map, and `rendering-2_5d` / Input mapping — select as `tapTile(reticle)`, a 0.4 s hold as the tile menu, select in route mode as a stop
- [ ] 2.6 Implement to green: `tv-remote-controls` / Placement follows the reticle — `pendingPlacementFollowsCamera` in `GameSession` (design D3), select confirms, Back cancels
- [ ] 2.7 Implement to green: `tv-remote-controls` / Toggle painting for roads and demolish — `paintActive`, one command per entered tile, Back stops painting before leaving the tool, tvOS tool strip hints (design D4)
- [ ] 2.8 Implement to green: `tv-remote-controls` / Focus moves between map and HUD and Game controller mapping — the mapper's focus and Back rules, Play/Pause, controller-to-event translation
- [ ] 2.9 Wire the tvOS views: the reticle overlay, `onMoveCommand`, `onExitCommand`, `onPlayPauseCommand`, select press and hold, `GCController` micro and extended gamepads feeding `RemoteInputMapper`, all inside `#if os(tvOS)`
- [ ] 2.10 Refactor under a green bar
- [ ] 2.11 Verify `make test-scenarios` is clean for `tv-remote-controls` and `rendering-2_5d`

## 3. M3 — TV HUD, focus and controls

- [ ] 3.1 Tests-first: translate `platform-shells` scenarios "TV layout on a 1920 × 1080 screen", "Stepped volume clamps at the top", "Settings has audio sliders", "Settings exposes credits", "tvOS session configured before engine construction", "Apple TV session advertises no activity" and "Pause reachable without a keyboard" into failing tests and confirm red
- [ ] 3.2 Implement to green: `platform-shells` / TV HUD layout — an idiom parameter on `HUDMetrics.layout(for:)` with the TV case (design D8), and focus sections for the map and the HUD
- [ ] 3.3 Implement to green: `platform-shells` / Settings exposes audio sliders — a `SteppedValueControl` with tested step and clamp logic, used on tvOS for the audio volumes and the manifest editor quantities (design D9)
- [ ] 3.4 Implement to green: `platform-shells` / tvOS audio session — widen the `os(iOS)` session and interruption guards in CityAudio to include tvOS
- [ ] 3.5 Implement to green: `platform-shells` / No Handoff on Apple TV and No keyboard shortcuts on Apple TV
- [ ] 3.6 Give every sheet and panel (Goals, Research, Standings, Routes, manifest editor, New Game, pause menu, Settings, Credits) a default focus and a Back exit; walk through each in the tvOS simulator with the verify skill and fix trapped or unreachable focus
- [ ] 3.7 Refactor under a green bar
- [ ] 3.8 Verify `make test-scenarios` is clean for `platform-shells`

## 4. M4 — tvOS saves in iCloud

- [ ] 4.1 Tests-first: translate the `persistence-save-load` scenarios "Save path resolution" and "Apple TV save path resolution", and every new `icloud-sync` scenario, into failing CityPersistence and CityUI tests against `InMemoryCloudKitClient`, and confirm red
- [ ] 4.2 Implement to green: `persistence-save-load` / Save location — a platform default for the `SaveStore` directory (Caches on tvOS), with the directory injectable so both paths are testable on the host
- [ ] 4.3 Add `listGames()` to `CloudKitClient` and to `InMemoryCloudKitClient`
- [ ] 4.4 Implement `CKContainerClient` against the private database (record type, `CKAsset` body, account status, list) with a live test behind `CITYBUILDER_CLOUDKIT_TESTS=1`
- [ ] 4.5 Implement to green: `icloud-sync` / Apple TV keeps saves in iCloud — upload after every save, restore missing or newer saves at launch before the title screen lists games, retry uploads for cache-only saves
- [ ] 4.6 Implement to green: `icloud-sync` / Apple TV warns when saves cannot be kept — the persistent title-screen notice
- [ ] 4.7 Refactor under a green bar
- [ ] 4.8 Verify `make test-scenarios` is clean for `persistence-save-load` and `icloud-sync`

## 5. M5 — CI and TestFlight

- [ ] 5.1 Add `build (CitybuilderTV)` with `generic/platform=tvOS Simulator` to the `ci.yml` build matrix and to `ci-ok`'s `needs`
- [ ] 5.2 Add a `tv` entry to the Fastfile `TARGETS` (scheme `CitybuilderTV`, match platform `tvos`, upload platform `appletvos`, `generic/platform=tvOS`) and a `platform :tv` release lane (design D11)
- [ ] 5.3 Add a `tvos` row (lane platform `tv`, artifact `build/fastlane/*.ipa`) to the `release-please.yml` TestFlight matrix, and update the README release section
- [ ] 5.4 Archive `CitybuilderTV` locally with fastlane (Homebrew Ruby on PATH) and run `xcrun altool --validate-app` on the `.ipa` before relying on CI
- [ ] 5.5 Deploy the CloudKit schema to the production environment in the CloudKit console — DEFERRED (requires Apple Developer account)
- [ ] 5.6 Upload a tvOS build to internal TestFlight from a release tag and install it on an Apple TV — DEFERRED (requires TestFlight and Apple TV hardware)

## 6. M6 — Hardware tuning

- [ ] 6.1 Tune the swipe pan speed curve and dead zone on the Siri Remote, both generations — DEFERRED (requires Apple TV hardware)
- [ ] 6.2 Measure fps on Apple TV HD and Apple TV 4K with a mid-game city — DEFERRED (requires Apple TV hardware)
- [ ] 6.3 Full playthrough with only the Siri Remote, then with a game controller — DEFERRED (requires Apple TV hardware)
- [ ] 6.4 Check that a save made on Apple TV survives deleting and reinstalling the app — DEFERRED (requires Apple TV hardware and iCloud account)
