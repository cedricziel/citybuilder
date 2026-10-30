import Foundation

/// A String Catalog (`.xcstrings`) flattened to the string units the rules read.
public struct Catalog: Sendable {
    /// One string unit: a whole value, or one plural form of it.
    public struct Unit: Sendable {
        public let form: String
        public let state: String
        public let value: String
    }

    public struct Entry: Sendable {
        public let key: String
        public let shouldTranslate: Bool
        public let localizations: [String: [Unit]]
    }

    public let name: String
    public let entries: [Entry]

    public init(name: String, json: Data) throws {
        let document = try JSONDecoder().decode(Document.self, from: json)
        self.name = name
        entries = document.strings.sorted { $0.key < $1.key }.map { key, string in
            Entry(
                key: key,
                shouldTranslate: string.shouldTranslate ?? true,
                localizations: (string.localizations ?? [:]).mapValues { $0.units() }
            )
        }
    }

    private struct Document: Decodable {
        let strings: [String: StringEntry]
    }

    private struct StringEntry: Decodable {
        let shouldTranslate: Bool?
        let localizations: [String: Localization]?
    }

    private struct StringUnit: Decodable {
        let state: String
        let value: String
    }

    /// A value or its variations. Device variations nest further variations;
    /// a unit's form is its leaf case name ("one", "other").
    private struct Localization: Decodable {
        let stringUnit: StringUnit?
        let variations: [String: [String: Localization]]?

        func units(form: String = "") -> [Unit] {
            var units = stringUnit.map { [Unit(form: form, state: $0.state, value: $0.value)] } ?? []
            for (_, cases) in (variations ?? [:]).sorted(by: { $0.key < $1.key }) {
                for (name, nested) in cases.sorted(by: { $0.key < $1.key }) {
                    units += nested.units(form: name)
                }
            }
            return units
        }
    }
}
