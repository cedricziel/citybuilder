import Foundation
import Testing
@testable import CityUI

/// Spec: `localization` / Player-visible text comes from the catalogs in the
/// player's language; A pseudo-locale exposes long and bypassed strings;
/// Arguments are formatted for the player's language.
struct GameTextTests {
    @Test("scenario: tests resolve text in a pinned language")
    func pinnedLanguage() {
        #expect(Language.current == .en)
        #expect(GameText.string("pause.resume") == "Resume")
    }

    /// `preferred(from:)` gets `Bundle.main.preferredLocalizations`, which
    /// already applies a per-app language over the system's.
    @Test("scenario: german locale shows german text")
    func germanLocale() {
        #expect(Language.preferred(from: ["de-DE", "en"], supported: [.en, .de]) == .de)
        #expect(GameText.string("pause.resume", in: .de) == "Weiter")
    }

    @Test("scenario: an unsupported language falls back to english")
    func unsupportedFallsBack() {
        let language = Language.preferred(from: ["fr", "es"], supported: [.en, .de])
        #expect(language == .en)
        #expect(GameText.string("pause.resume", in: language) == "Resume")
    }

    @Test("German is not offered to players until it ships")
    func germanNotShippedYet() {
        #expect(Language.preferred(from: ["de"]) == .en)
    }

    @Test("a missing key shows the key, not an empty string")
    func missingKey() {
        #expect(GameText.string("no.such.key", in: .de) == "no.such.key")
    }

    @Test("format arguments fill in the player's language")
    func formatArguments() {
        #expect(GameText.string("pause.saveFailed", "disk full") == "Couldn't save: disk full")
        #expect(GameText.string("pause.saveFailed", "disk full", in: .de) == "Speichern fehlgeschlagen: disk full")
    }

    @Test("scenario: the pseudo-locale lengthens and marks a string")
    func pseudoLengthens() {
        let label = GameText.string("pause.resume", in: .pseudo)
        #expect(label.hasPrefix("["))
        #expect(label.hasSuffix("]"))
        #expect(!label.contains { "Resume".contains($0) })
        #expect(Double(label.count) >= 1.4 * Double("Resume".count))
    }

    @Test("scenario: the pseudo-locale keeps placeholders")
    func pseudoKeepsPlaceholders() {
        let template = PseudoLocale.transform("%lld left the town before {date}.")
        #expect(template.contains("%lld"))
        #expect(template.contains("{date}"))
        let filled = String(format: template, 3).replacingOccurrences(of: "{date}", with: "Spring 1203")
        #expect(filled.contains("3"))
        #expect(filled.contains("Spring 1203"))
    }

    @Test("the pseudo-locale keeps positional specifiers")
    func pseudoKeepsPositional() {
        let template = PseudoLocale.transform("%1$@ enters the %2$@")
        #expect(template.contains("%1$@"))
        #expect(template.contains("%2$@"))
    }

    @Test("scenario: numbers use the locale's grouping")
    func numberGrouping() {
        #expect(GameText.number(1500, in: .de) == "1.500")
        #expect(GameText.number(1500, in: .en) == "1,500")
    }

    @Test("the pseudo-locale is chosen by its launch argument")
    func pseudoLaunchArgument() throws {
        let defaults = try #require(UserDefaults(suiteName: "GameTextTests.pseudo"))
        defer { defaults.removePersistentDomain(forName: "GameTextTests.pseudo") }
        #expect(Language.atLaunch(preferredLocalizations: ["en"], defaults: defaults) == .en)
        defaults.set(true, forKey: Language.pseudoLocaleDefaultsKey)
        #expect(Language.atLaunch(preferredLocalizations: ["en"], defaults: defaults) == .pseudo)
    }
}
