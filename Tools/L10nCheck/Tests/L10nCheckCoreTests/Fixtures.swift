import Foundation
@testable import L10nCheckCore

/// A test catalog entry: English and German as a single value or plural forms.
struct Entry {
    enum Value {
        case single(String)
        case plural([String: String])
    }

    let en: Value
    let de: Value?
    var state = "translated"
    var shouldTranslate = true
}

extension Entry {
    init(en: String, de: String?, state: String = "translated", shouldTranslate: Bool = true) {
        self.init(en: .single(en), de: de.map(Value.single), state: state, shouldTranslate: shouldTranslate)
    }
}

let testGlossary = Glossary(
    terms: [Glossary.Term(term: "order", german: "Auftrag", avoid: ["Bestellung", "Order"])],
    formal: ["Sie können", "Sie haben", "Ihnen"]
)

/// Writes `entries` as an `.xcstrings` document and runs every rule over it.
func check(
    _ entries: [String: Entry], sources: [SourceFile] = [], glossary: Glossary = testGlossary
) throws -> [Finding] {
    func unit(_ value: String, _ state: String) -> [String: Any] {
        ["stringUnit": ["state": state, "value": value]]
    }
    func localization(_ value: Entry.Value, _ state: String) -> [String: Any] {
        switch value {
        case let .single(text): unit(text, state)
        case let .plural(forms): ["variations": ["plural": forms.mapValues { unit($0, state) }]]
        }
    }
    var strings: [String: Any] = [:]
    for (key, entry) in entries {
        var localizations = ["en": localization(entry.en, "translated")]
        if let de = entry.de { localizations["de"] = localization(de, entry.state) }
        var item: [String: Any] = ["localizations": localizations]
        if !entry.shouldTranslate { item["shouldTranslate"] = false }
        strings[key] = item
    }
    let json = try JSONSerialization.data(withJSONObject: ["sourceLanguage": "en", "version": "1.0", "strings": strings])
    let catalog = try Catalog(name: "Test.xcstrings", json: json)
    return L10nCheck.run(catalogs: [catalog], sources: sources, glossary: glossary)
}
