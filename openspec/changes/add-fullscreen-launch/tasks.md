## 1. M1 — iOS Info.plist lock to fullscreen

- [x] 1.1 Tests-first: translate `#### Scenario: iPad app launches fullscreen with no multitasking` into a failing test — `scripts/check-ios-fullscreen-lock.sh` reads the generated `Info.plist` and asserts `UIRequiresFullScreen == true`.
- [x] 1.2 Implement to green: add `UIRequiresFullScreen: true` to the `CitybuilderiOS` target's `info.properties` block in `project.yml`. Run `make generate`. Verified xcodegen materialized the key into the generated `Info.plist`.
- [ ] 1.3 Verify on iPad simulator: launch the app; Split View / Slide Over / Stage Manager affordances are no longer offered for this app in the system multitasking switcher. — DEFERRED (interactive smoke).

## 2. M2 — Mac launch-fullscreen behavior

- [x] 2.1 Tests-first: translate `#### Scenario: Mac launches fullscreen by default`, `#### Scenario: Mac remembers a manual exit-fullscreen preference`, and `#### Scenario: Mac re-launches fullscreen after a user re-enters fullscreen` into failing tests in a new `CitybuilderMacAppTests` target (or as Swift tests on a small `MacLaunchFullscreenPreferences` value-type extracted into CityUI for headless testing). Confirm red. — Landed as the second path: headless-testable `MacLaunchFullscreenPreferences` in CityUI.
- [x] 2.2 Implement to green: extract a `MacLaunchFullscreenPreferences` helper that wraps `UserDefaults.standard`'s `Citybuilder.macLaunchFullscreen: Bool` (default `true`). Headless-testable.
- [x] 2.3 Implement to green: in `CitybuilderMacApp`, add `.onAppear { applyLaunchFullscreenIfNeeded() }` to the WindowGroup's root view via a `MacFullscreenTracker` that also owns the notification observers (so they outlive the SwiftUI view lifetime).
- [x] 2.4 Implement to green: register two `NotificationCenter` observers on `NSWindow.willEnterFullScreenNotification` / `willExitFullScreenNotification` that write the preference flag. Use the `MacLaunchFullscreenPreferences` helper from 2.2.

## 3. M3 — README + Settings disclosure

- [x] 3.1 README: add a short "Display" section noting iPad fullscreen lock (multitasking disabled by design) and Mac launch-fullscreen behavior (remembered across launches).
- [ ] 3.2 (Optional) The platform Settings surface gains an "Always launch fullscreen" toggle on Mac that mirrors the UserDefaults key. — DEFERRED until the existing settings sheet has a Display section to add to.

## 4. M4 — Polish + verification

- [x] 4.1 Final `make test && make lint && make format`.
- [ ] 4.2 Visual smoke check on iPad simulator: confirm app is locked fullscreen. — DEFERRED (interactive).
- [ ] 4.3 Visual smoke check on Mac: launch app → goes fullscreen. Cmd-Ctrl-F to exit → relaunch → comes up windowed. Re-enter fullscreen → relaunch → comes up fullscreen. — DEFERRED (interactive).
