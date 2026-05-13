import Foundation
import Testing
@testable import CityUI

// Tests for the Mac launch-fullscreen preference added by
// `add-fullscreen-launch` → M2. Scenarios from
// openspec/changes/add-fullscreen-launch/specs/platform-shells/spec.md
// under `Requirement: Mac launches fullscreen by default` and
// `Requirement: Mac remembers user-driven fullscreen transitions`.

private func suiteDefaults() -> UserDefaults {
    let name = "MacLaunchFullscreenPreferencesTests-\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: name)!
    defaults.removePersistentDomain(forName: name)
    return defaults
}

@Test("scenario: mac launches fullscreen by default")
func scenarioMacLaunchesFullscreenByDefault() {
    let prefs = MacLaunchFullscreenPreferences(defaults: suiteDefaults())
    // Fresh suite has no stored value — the preference defaults true.
    #expect(prefs.shouldLaunchFullscreen == true)
}

@Test("scenario: mac respects an explicit windowed preference")
func scenarioMacRespectsAnExplicitWindowedPreference() {
    let defaults = suiteDefaults()
    let prefs = MacLaunchFullscreenPreferences(defaults: defaults)
    prefs.setShouldLaunchFullscreen(false)
    let reloaded = MacLaunchFullscreenPreferences(defaults: defaults)
    #expect(reloaded.shouldLaunchFullscreen == false)
}

@Test("scenario: mac remembers a manual exit-fullscreen preference")
func scenarioMacRemembersAManualExitFullscreenPreference() {
    // Simulate the willExitFullScreenNotification flow — the observer
    // writes `false` to the preference. The next launch reads back
    // `false`.
    let defaults = suiteDefaults()
    MacLaunchFullscreenPreferences(defaults: defaults).setShouldLaunchFullscreen(false)
    let next = MacLaunchFullscreenPreferences(defaults: defaults)
    #expect(next.shouldLaunchFullscreen == false)
}

@Test("scenario: mac re-launches fullscreen after a user re-enters fullscreen")
func scenarioMacReLaunchesFullscreenAfterAUserReEntersFullscreen() {
    // Flow: user exits (writes false), then re-enters (writes true),
    // then relaunches.
    let defaults = suiteDefaults()
    let prefs = MacLaunchFullscreenPreferences(defaults: defaults)
    prefs.setShouldLaunchFullscreen(false)
    prefs.setShouldLaunchFullscreen(true)
    let next = MacLaunchFullscreenPreferences(defaults: defaults)
    #expect(next.shouldLaunchFullscreen == true)
}
