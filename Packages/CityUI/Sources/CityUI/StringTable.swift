import Foundation

/// A String Catalog, read from its `.xcstrings` JSON or from the tables
/// Xcode compiles it into. SwiftPM 6.3 copies an `.xcstrings` file
/// unchanged, so `Bundle`'s own lookup finds nothing under `swift test`,
/// while an Xcode archive compiles the file even though the package says
/// to copy it.
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

    /// The tables an Xcode archive compiles the catalogs into: each
    /// `<language>.lproj` holds `.strings` for text and `.stringsdict` for
    /// plurals.
    init(compiledIn bundle: URL) {
        let lprojs = (try? FileManager.default.contentsOfDirectory(at: bundle, includingPropertiesForKeys: nil)) ?? []
        var entries: [String: [String: Value]] = [:]
        for lproj in lprojs where lproj.pathExtension == "lproj" {
            let language = lproj.deletingPathExtension().lastPathComponent
            for file in (try? FileManager.default.contentsOfDirectory(at: lproj, includingPropertiesForKeys: nil)) ?? [] {
                guard let data = try? Data(contentsOf: file),
                      let table = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
                else { continue }
                let plurals = file.pathExtension == "stringsdict"
                for (key, value) in table {
                    entries[key, default: [:]][language] = plurals ? Self.plural(value) : (value as? String).map(Value.text)
                }
            }
        }
        self.entries = entries
    }

    /// A `.stringsdict` entry whose whole text is one plural variable, the
    /// shape a catalog's plural variation compiles to.
    private static func plural(_ entry: Any) -> Value? {
        guard let entry = entry as? [String: Any], let format = entry["NSStringLocalizedFormatKey"] as? String,
              format.hasPrefix("%#@"), format.hasSuffix("@"),
              let variable = entry[String(format.dropFirst(3).dropLast())] as? [String: Any]
        else { return nil }
        return .plural(variable.compactMapValues { $0 as? String }.filter { !$0.key.hasPrefix("NSString") })
    }

    /// One table holding every key of `tables`.
    init(merging tables: [StringTable]) {
        entries = tables.reduce(into: [:]) { $0.merge($1.entries) { first, _ in first } }
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
