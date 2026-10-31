import Foundation
import Testing
@testable import CityUI

/// GameText reads the catalog whether the toolchain copied its `.xcstrings`
/// JSON (SwiftPM 6.3) or compiled it into `.lproj` tables (an Xcode archive).
struct StringTableTests {
    static let json = Data("""
    {"sourceLanguage":"en","version":"1.0","strings":{
      "pause.resume":{"localizations":{
        "en":{"stringUnit":{"state":"translated","value":"Resume"}},
        "de":{"stringUnit":{"state":"translated","value":"Weiter"}}}},
      "count.good":{"localizations":{
        "en":{"variations":{"plural":{"one":{"stringUnit":{"state":"translated","value":"%lld good"}},
                                      "other":{"stringUnit":{"state":"translated","value":"%lld goods"}}}}},
        "de":{"variations":{"plural":{"one":{"stringUnit":{"state":"translated","value":"%lld Ware"}},
                                      "other":{"stringUnit":{"state":"translated","value":"%lld Waren"}}}}}}},
      "only.english":{"localizations":{"en":{"stringUnit":{"state":"translated","value":"English"}}}}
    }}
    """.utf8)

    @Test("a table reads values per language")
    func values() throws {
        let table = try StringTable(json: Self.json)
        #expect(table.format(for: "pause.resume", in: "de", arguments: []) == "Weiter")
        #expect(table.format(for: "pause.resume", in: "en", arguments: []) == "Resume")
    }

    @Test("a missing language falls back to English, a missing key to nil")
    func fallbacks() throws {
        let table = try StringTable(json: Self.json)
        #expect(table.format(for: "only.english", in: "de", arguments: []) == "English")
        #expect(table.format(for: "no.such.key", in: "de", arguments: []) == nil)
    }

    @Test("plural forms follow the first integer argument")
    func plurals() throws {
        let table = try StringTable(json: Self.json)
        #expect(table.format(for: "count.good", in: "en", arguments: [1]) == "%lld good")
        #expect(table.format(for: "count.good", in: "en", arguments: [0]) == "%lld goods")
        #expect(table.format(for: "count.good", in: "de", arguments: ["x", 3]) == "%lld Waren")
    }

    @Test("an archived app's compiled tables read like the catalog")
    func compiledTables() throws {
        let bundle = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: bundle) }
        for (language, resume, one, other) in [("en", "Resume", "%lld good", "%lld goods"), ("de", "Weiter", "%lld Ware", "%lld Waren")] {
            let lproj = bundle.appendingPathComponent("\(language).lproj")
            try FileManager.default.createDirectory(at: lproj, withIntermediateDirectories: true)
            try PropertyListSerialization.data(fromPropertyList: ["pause.resume": resume], format: .binary, options: 0)
                .write(to: lproj.appendingPathComponent("Localizable.strings"))
            let plural: [String: Any] = ["count.good": [
                "NSStringLocalizedFormatKey": "%#@value@",
                "value": ["NSStringFormatSpecTypeKey": "NSStringPluralRuleType", "one": one, "other": other]
            ]]
            try PropertyListSerialization.data(fromPropertyList: plural, format: .xml, options: 0)
                .write(to: lproj.appendingPathComponent("Localizable.stringsdict"))
        }
        try PropertyListSerialization.data(fromPropertyList: ["only.english": "English"], format: .binary, options: 0)
            .write(to: bundle.appendingPathComponent("en.lproj/GameData.strings"))

        let table = StringTable(compiledIn: bundle)
        #expect(table.format(for: "pause.resume", in: "de", arguments: []) == "Weiter")
        #expect(table.format(for: "only.english", in: "de", arguments: []) == "English")
        #expect(table.format(for: "count.good", in: "de", arguments: [1]) == "%lld Ware")
        #expect(table.format(for: "count.good", in: "en", arguments: [2]) == "%lld goods")
        #expect(table.format(for: "no.such.key", in: "en", arguments: []) == nil)
    }

    @Test("the shipped catalog is in the bundle as JSON")
    func shippedCatalog() {
        #expect(GameText.string("pause.resume", in: .de) == "Weiter")
        #expect(GameText.string("pause.saveFailed", "voll", in: .de) == "Speichern fehlgeschlagen: voll")
    }
}
