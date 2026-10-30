import Foundation
import Testing
@testable import CityUI

/// GameText reads the `.xcstrings` JSON itself, so lookups don't depend on
/// whether the toolchain compiled the catalog (SwiftPM 6.3 copies it as is).
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

    @Test("the shipped catalog is in the bundle as JSON")
    func shippedCatalog() {
        #expect(GameText.string("pause.resume", in: .de) == "Weiter")
        #expect(GameText.string("pause.saveFailed", "voll", in: .de) == "Speichern fehlgeschlagen: voll")
    }
}
