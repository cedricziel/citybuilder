import Foundation
import SwiftUI
import Synchronization

/// A language the game's text resolves in. Spec: `localization`; design D3
/// and D10 of `add-localization`.
public enum Language: String, Sendable {
    case en, de
    /// English, accented, padded and bracketed to expose long and bypassed text.
    case pseudo

    /// The languages players get. German joins once all of it ships (design D9).
    public static let shipped: [Language] = [.en]
    /// `-CBPseudoLocale YES` on launch turns the pseudo-locale on.
    static let pseudoLocaleDefaultsKey = "CBPseudoLocale"

    private static let storage = Mutex(Language.en)

    /// The language every lookup uses unless it names one. English until the
    /// app sets it at launch, so tests never depend on the machine's language.
    public static var current: Language {
        get { storage.withLock { $0 } }
        set { storage.withLock { $0 = newValue } }
    }

    /// The first preferred localization that is supported, else English.
    /// Pass `Bundle.main.preferredLocalizations`: it already applies a
    /// per-app language chosen in Settings.
    public static func preferred(from localizations: [String], supported: [Language] = shipped) -> Language {
        for localization in localizations {
            let code = localization.split(whereSeparator: { $0 == "-" || $0 == "_" }).first.map(String.init)
            if let language = supported.first(where: { $0.rawValue == code }) { return language }
        }
        return .en
    }

    public static func atLaunch(preferredLocalizations: [String], defaults: UserDefaults) -> Language {
        defaults.bool(forKey: pseudoLocaleDefaultsKey) ? .pseudo : preferred(from: preferredLocalizations)
    }

    /// Sets `current` from the app bundle and the launch arguments. App shells call it first thing.
    public static func adoptAtLaunch() {
        current = atLaunch(preferredLocalizations: Bundle.main.preferredLocalizations, defaults: .standard)
    }

    private static let english = Locale(identifier: "en_US"), german = Locale(identifier: "de_DE")

    public var locale: Locale {
        self == .de ? Self.german : Self.english
    }

    /// The catalog column the language reads; the pseudo-locale transforms English.
    var catalogLanguage: Language {
        self == .pseudo ? .en : self
    }
}

/// Every player-visible string goes through here. Keys are literal at the
/// call site (`GameText.string("pause.resume")`, `Text(l10n: "pause.title")`)
/// so `l10n-check` can find them.
public enum GameText {
    /// The catalog, copied into the bundle as JSON (see `StringTable`).
    private static let table: StringTable? = Bundle.module.url(forResource: "Localizable", withExtension: "xcstrings")
        .flatMap { try? StringTable(json: Data(contentsOf: $0)) }

    /// The text for `key` in `language`, its format arguments filled. A
    /// missing key shows as itself.
    public static func string(_ key: String, _ arguments: any CVarArg..., in language: Language = .current) -> String {
        string(key, arguments: arguments, in: language)
    }

    static func string(_ key: String, arguments: [any CVarArg], in language: Language) -> String {
        var format = table?.format(for: key, in: language.catalogLanguage.rawValue, arguments: arguments) ?? key
        if language == .pseudo { format = PseudoLocale.transform(format) }
        return arguments.isEmpty ? format : String(format: format, locale: language.locale, arguments: arguments)
    }

    /// A name as it reads inside a sentence: English lowercases common
    /// nouns there, German keeps their capital.
    public static func inSentence(_ name: String, in language: Language = .current) -> String {
        language == .de ? name : name.lowercased()
    }

    public static func number(_ value: Int, in language: Language = .current) -> String {
        value.formatted(.number.locale(language.locale))
    }
}

/// Design D10: letters become accented look-alikes, the text grows to at
/// least 140% and sits in brackets. Format specifiers and `{names}` stay.
public enum PseudoLocale {
    private static let plain = Array("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ")
    private static let accented = Array("àƀçðéƒĝĥîĵķļɱñöþǫŕšţûṽŵẋýžÀƁÇÐÉƑĜĤÎĴĶĻṀÑÖÞǪŔŠŢÛṼŴẊÝŽ")
    private static let letters = Dictionary(uniqueKeysWithValues: zip(plain, accented))
    private nonisolated(unsafe) static let placeholder = /%(?:\d+\$)?[-+ 0#]*\d*(?:\.\d+)?(?:ll|l|h)?[@dDuUxXoOfeEgGcCsSp%]|\{[A-Za-z]+\}/

    public static func transform(_ text: String) -> String {
        var result = ""
        var rest = text[...]
        while let match = rest.firstMatch(of: placeholder) {
            result += accent(rest[..<match.range.lowerBound]) + rest[match.range]
            rest = rest[match.range.upperBound...]
        }
        result += accent(rest)
        let padding = String(repeating: "~", count: max(1, Int((Double(text.count) * 0.4).rounded(.up))))
        return "[\(result) \(padding)]"
    }

    private static func accent(_ text: Substring) -> String {
        String(text.map { letters[$0] ?? $0 })
    }
}

public extension Text {
    /// A catalog string in the current language, its format arguments filled.
    init(l10n key: String, _ arguments: any CVarArg...) {
        self.init(verbatim: GameText.string(key, arguments: arguments, in: .current))
    }
}
