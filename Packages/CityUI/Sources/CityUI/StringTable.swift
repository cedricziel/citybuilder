import Foundation

/// A String Catalog read from its `.xcstrings` JSON. GameText reads the
/// catalog itself rather than through `Bundle`'s compiled tables: SwiftPM
/// 6.3 copies an `.xcstrings` file unchanged instead of compiling it, so a
/// `Bundle` lookup would find nothing under `swift test` there.
struct StringTable: Sendable {
    private enum Value: Sendable {
        case text(String)
        /// Plural category ("one", "other") to text.
        case plural([String: String])
    }

    /// Key to language code to value.
    private let entries: [String: [String: Value]]

    init(json: Data) throws {
        let document = try JSONDecoder().decode(Document.self, from: json)
        entries = document.strings.mapValues { entry in
            (entry.localizations ?? [:]).compactMapValues { localization in
                if let plural = localization.variations?.plural {
                    return .plural(plural.compactMapValues { $0.stringUnit?.value })
                }
                return localization.stringUnit.map { .text($0.value) }
            }
        }
    }

    /// The format string for `key` in `language`, else in English; nil when
    /// no catalog has the key. A plural entry picks its form from the first
    /// integer among `arguments`.
    func format(for key: String, in language: String, arguments: [any CVarArg]) -> String? {
        guard let localizations = entries[key], let value = localizations[language] ?? localizations["en"] else { return nil }
        switch value {
        case let .text(text):
            return text
        case let .plural(forms):
            let count = arguments.lazy.compactMap { ($0 as? any BinaryInteger).map { Int($0) } }.first
            return forms[Self.pluralCategory(count, language: language)] ?? forms["other"]
        }
    }

    /// CLDR's integer rule for English and German: "one" for exactly 1.
    /// A language with other categories adds its rule here.
    private static func pluralCategory(_ count: Int?, language _: String) -> String {
        count == 1 ? "one" : "other"
    }

    private struct Document: Decodable {
        let strings: [String: Entry]
    }

    private struct Entry: Decodable {
        let localizations: [String: Localization]?
    }

    private struct Localization: Decodable {
        let stringUnit: StringUnit?
        let variations: Variations?
    }

    private struct Variations: Decodable {
        let plural: [String: Localization]?
    }

    private struct StringUnit: Decodable {
        let value: String
    }
}
