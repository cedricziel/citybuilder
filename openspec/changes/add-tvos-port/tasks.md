## 1. M1 — tvOS target that builds in CI and launches

- [ ] 1.1 Extend the verify skill (`.claude/skills/verify/SKILL.md`) with a tvOS section: pick an Apple TV simulator, build with `-destination 'platform=tvOS Simulator,id=…'`, find the app under `Debug-appletvsimulator`, launch it, and send remote presses
- [ ] 1.2 Tests-first: update the existing `platform-shells` tests for "Universal Purchase one buy" and add "App targets share one bundle identifier" (parse `project.yml` in the test); add failing tests for "Stepped volume clamps at the top" and the `persistence-save-load` scenarios "Save path resolution" and "Apple TV save path resolution" (directory chosen through an injected platform value); confirm red
- [ ] 1.3 Add `.tvOS(.v18)` to all six packages and `tvOS: "18.0"` to `project.yml` `options.deploymentTarget`; run `scripts/check-no-apple-ui-imports.sh` to confirm CityCore sources are unchanged
- [ ] 1.4 Narrow the touch-location guards from `canImport(UIKit)` to `os(iOS)` at `IsoWorldScene.swift:103`, `:119` and `IsoWorldScene+LongPress.swift:3` (design D1/D3 context); keep image and colour loading on `canImport(UIKit)`
- [ ] 1.5 Compile out on tvOS: `panGesture`, `zoomGesture` and both `.simultaneousGesture` calls (`CityRootView+Gestures.swift`, `CityUI.swift:53-54`); the `.roundedBorder` text-field style (`NewGameDialogView.swift:193`); `keyboardShortcut` in `BuildRailView`, `NewGameDialogView`, `PauseMenuView` and `StatusPillView`
- [ ] 1.6 Implement to green: `platform-shells` / Settings exposes audio sliders — `SteppedValue` and `SteppedValueControl` with hold-to-repeat (design D10), used on tvOS for all four audio sliders and the manifest editor `Stepper`; credits show links as text on tvOS
- [ ] 1.7 Implement to green: `persistence-save-load` / Save location — Caches default on tvOS through the injectable directory
- [ ] 1.8 Implement to green: `platform-shells` / Universal Apple platform support — `CitybuilderTV` target and scheme in `project.yml` (shared bundle id, the atlases and audio, CloudKit and key-value-store entitlements without iCloud Documents), `Apps/CitybuilderTV/` with the app entry and Info.plist (`ITSAppUsesNonExemptEncryption: false`, `GCSupportedGameControllers` for ExtendedGamepad, MicroGamepad and DirectionalGamepad, `GCSupportsControllerUserInteraction`)
- [ ] 1.9 Extend `scripts/generate-app-icon.swift` to write the tvOS `.brandassets`: 2–5-layer image stacks with only the back layer opaque, App Icon 400×240 @1x/@2x, App Store 1280×768, Top Shelf 1920×720 and Top Shelf Wide 2320×720 @1x/@2x (design D12)
- [ ] 1.10 Add `SCHEME_TV` and a tvOS line to the `Makefile` `build` target; add `build (CitybuilderTV)` with `generic/platform=tvOS Simulator` to the `ci.yml` build matrix and to `ci-ok`'s `needs`, installing the tvOS simulator runtime on the runner when missing
- [ ] 1.11 `make generate`, build each package for `generic/platform=tvOS Simulator`, build `CitybuilderTV`, and launch it to the title screen with the verify skill
- [ ] 1.12 Refactor under a green bar
- [ ] 1.13 Run `SCENARIO_COVERAGE_STRICT=1 make test-scenarios` and confirm no uncovered scenario in `platform-shells` or `persistence-save-load` from this change

## 2. M2 — Remote and controller input

- [ ] 2.1 Spike: host the map in a `GCEventViewController` with `controllerUserInteractionEnabled = false` in the tvOS simulator, and log the event shapes for swipes, edge clicks, select, Play/Pause and Back from the simulator remote; record the findings in design D3
- [ ] 2.2 Tests-first: translate every `tv-remote-controls` scenario and the `rendering-2_5d` scenarios "Remote select dispatched as a tap on the reticle tile" and "Building placement is confirmed by default on Apple TV" into failing CityUI tests against `RemoteInputMapper` and `GameControllerAdapter` with an injected clock (design D4); confirm red
- [ ] 2.3 Implement to green: `tv-remote-controls` / One input owner per mode — the mapper's map and HUD modes and focus-change events
- [ ] 2.4 Implement to green: `tv-remote-controls` / Reticle marks the target tile — the camera-center clamp in `GameSession` on tvOS (design D1) and the direction hints using `NudgeDirection` (design D2)
- [ ] 2.5 Implement to green: `tv-remote-controls` / Reticle tooltip — 0.5 s rest through `HoverTooltipController`, buildings only, hidden while pending or painting
- [ ] 2.6 Implement to green: `tv-remote-controls` / Remote pans the map and Zoom without pinch — zoom-scaled swipe pan, click steps, zoom buttons ×1.5, holding Play/Pause cycles 2.0 / 1.0 / 0.5, trigger zoom
- [ ] 2.7 Implement to green: `tv-remote-controls` / Select and hold on the map, and `rendering-2_5d` / Input mapping — tap below 0.4 s, hold for the tile menu, select on the selected building focuses its callout, route stops
- [ ] 2.8 Implement to green: `tv-remote-controls` / Placement follows the reticle, and `rendering-2_5d` / Palette-armed buildings and Tap is suppressed — `confirmsBuildingPlacement` on for tvOS, `pendingPlacementFollowsCamera`, confirm-and-repeat, Back to inspect (design D5)
- [ ] 2.9 Implement to green: `tv-remote-controls` / Road painting and Demolish acts on one building at a time — click-only painting, one-shot demolish, reticle styles (design D6)
- [ ] 2.10 Implement to green: `tv-remote-controls` / Back steps out one level at a time and Play/Pause moves focus between map and HUD (design D7, D8)
- [ ] 2.11 Implement to green: `tv-remote-controls` / Game controller mapping — `GameControllerAdapter` from button-state snapshots
- [ ] 2.12 Wire the tvOS map view: the `GCEventViewController` host, the reticle overlay with its hints and styles, and `GCController` callbacks feeding `GameControllerAdapter`, all inside `#if os(tvOS)`
- [ ] 2.13 Wire the tvOS handover: switch `controllerUserInteractionEnabled` when focus moves between map and HUD; the title screen attaches no exit handler; the pause menu resumes on Back
- [ ] 2.14 Refactor under a green bar
- [ ] 2.15 Run `SCENARIO_COVERAGE_STRICT=1 make test-scenarios` and confirm no uncovered scenario in `tv-remote-controls` or `rendering-2_5d` from this change

## 3. M3 — TV HUD and focus

- [ ] 3.1 Tests-first: translate the `platform-shells` scenarios "Apple TV HUD" and "Apple TV tool strip hints" into failing CityUI tests; confirm red
- [ ] 3.2 Implement to green: `platform-shells` / Adaptive HUD per idiom — an idiom parameter on `HUDLayout.make` replacing `isPhone`/`isTouch`, with the TV case (design D9)
- [ ] 3.3 Implement to green: `platform-shells` / Tool strip — Apple TV hints
- [ ] 3.4 Add focus sections and focus guides linking the build rail, top bar, inspector callout and route overlay (design D7)
- [ ] 3.5 Default focus and Back exit for the Goals, Research, Standings and Routes panels; walk through each in the tvOS simulator with the verify skill
- [ ] 3.6 Default focus and Back exit for the manifest editor, New Game (city name prefilled), pause menu, Settings and Credits; walk through each in the tvOS simulator with the verify skill
- [ ] 3.7 Add a test that the tvOS audio session path configures `.playback` with `.mixWithOthers` before engine construction, using the existing `PlatformAudioSession` seam (the guard already covers tvOS)
- [ ] 3.8 Refactor under a green bar
- [ ] 3.9 Run `SCENARIO_COVERAGE_STRICT=1 make test-scenarios` and confirm no uncovered scenario in `platform-shells` from this change

## 4. M4 — tvOS saves in iCloud (requires `add-cloudkit-client`)

- [ ] 4.1 Tests-first: translate every `icloud-sync` scenario in this change into failing tests — `TVSaveSync` scenarios in CityPersistence against `InMemoryCloudKitClient`, and the title-screen notice against `TitleScreenModel` in CityUI; confirm red
- [ ] 4.2 Implement to green: `icloud-sync` / Apple TV keeps saves in iCloud — upload after every save, a pending-upload list in `UserDefaults`, retries at the next save, at launch and on becoming active (design D11)
- [ ] 4.3 Implement to green: `icloud-sync` / Last-write-wins conflict policy v0 — restore at launch downloads games with no local copy without a prompt; games with both copies go through the existing policy
- [ ] 4.4 Implement to green: `icloud-sync` / iCloud account not signed in — the Apple TV title-screen notice through `TitleScreenModel`
- [ ] 4.5 Wire `TVSaveSync` into the tvOS app with the production CloudKit client
- [ ] 4.6 Refactor under a green bar
- [ ] 4.7 Run `SCENARIO_COVERAGE_STRICT=1 make test-scenarios` and confirm no uncovered scenario in `icloud-sync` from this change

## 5. M5 — TestFlight

- [ ] 5.1 Add the `tv` entry to the Fastfile `TARGETS` (`target: "CitybuilderTV"`, match platform `tvos`, upload platform `appletvos`, `generic/platform=tvOS`, `.ipa`) and `build` and `release` lanes under `platform :appletvos` (design D12)
- [ ] 5.2 Add a `tvos` row (lane platform `appletvos`, artifact `build/fastlane/*.ipa`) to the `release-please.yml` TestFlight matrix; update the README release section, including the line saying there is no tvOS app target yet
- [ ] 5.3 Archive `CitybuilderTV` locally with fastlane (Homebrew Ruby on PATH) and run `xcrun altool --validate-app` on the `.ipa` before relying on CI
- [ ] 5.4 Upload a tvOS build to internal TestFlight from a release tag and install it on an Apple TV — DEFERRED (requires TestFlight and Apple TV hardware)

## 6. M6 — Hardware checks

- [ ] 6.1 Confirm the input spike's event shapes and tune swipe gain and dead zone on both Siri Remote generations — DEFERRED (requires Apple TV hardware)
- [ ] 6.2 Measure fps on Apple TV HD and Apple TV 4K with a mid-game city — DEFERRED (requires Apple TV hardware)
- [ ] 6.3 Full playthrough with only the Siri Remote, then with a game controller — DEFERRED (requires Apple TV hardware)
- [ ] 6.4 Check that a city survives deleting and reinstalling the app with iCloud signed in — DEFERRED (requires Apple TV hardware and iCloud account)
