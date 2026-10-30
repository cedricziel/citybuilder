import Foundation

/// One rule broken by one key. `location` is the catalog or `file:line`.
public struct Finding: Equatable, Sendable, CustomStringConvertible {
    public let location: String
    public let key: String
    public let message: String

    public var description: String {
        "\(location): \(key): \(message)"
    }
}

public struct SourceFile: Sendable {
    public let path: String
    public let text: String

    public init(path: String, text: String) {
        self.path = path
        self.text = text
    }
}

/// The spec's German glossary: the words to avoid per term, and the
/// phrases of formal address.
public struct Glossary: Decodable, Sendable {
    public struct Term: Decodable, Sendable {
        public let term: String
        public let german: String
        public let avoid: [String]
    }

    public let terms: [Term]
    public let formal: [String]
}

/// Spec: `localization` / A completeness check guards the catalogs.
public enum L10nCheck {
    public static func run(catalogs: [Catalog], sources: [SourceFile], glossary: Glossary) -> [Finding] {
        let entries = catalogs.flatMap { catalog in catalog.entries.map { (catalog.name, $0) } }
        let known = Set(entries.map(\.1.key))
        return entries.flatMap { name, entry in
            entryFindings(entry, glossary).map { Finding(location: name, key: entry.key, message: $0) }
        } + unknownKeys(in: sources, known: known)
    }

    static func entryFindings(_ entry: Catalog.Entry, _ glossary: Glossary) -> [String] {
        guard entry.shouldTranslate else { return [] }
        guard let german = entry.localizations["de"], !german.isEmpty else { return ["no German value"] }
        let english = entry.localizations["en"] ?? []
        var messages: [String] = german.filter { $0.state != "translated" }.map { "German form '\($0.form)' is \($0.state)" }
        messages += placeholderMismatches(english: english, german: german)
        for unit in german {
            if let article = articleBeforePlaceholder.firstMatchedText(in: unit.value) {
                messages.append("article before a noun placeholder: '\(article)'")
            }
            for term in glossary.terms {
                for word in term.avoid where unit.value.containsWholeWord(word) {
                    messages.append("uses '\(word)'; the glossary says '\(term.german)' for '\(term.term)'")
                }
            }
            for phrase in glossary.formal where unit.value.containsWholeWord(phrase) {
                messages.append("formal address '\(phrase)'; address the player with du")
            }
        }
        return messages
    }

    /// Every German form must carry exactly the placeholders of the English
    /// text: a plural form against the same English form, else against
    /// English's `other` (German and English plural categories can differ).
    /// Positional specifiers may be reordered.
    static func placeholderMismatches(english: [Catalog.Unit], german: [Catalog.Unit]) -> [String] {
        let byForm = Dictionary(english.map { ($0.form, placeholders(in: $0.value)) }, uniquingKeysWith: { first, _ in first })
        return german.compactMap { unit in
            guard let expected = byForm[unit.form] ?? byForm["other"] ?? byForm.values.first else { return nil }
            let actual = placeholders(in: unit.value)
            guard actual != expected else { return nil }
            let missing = expected.subtracting(actual).sorted(), extra = actual.subtracting(expected).sorted()
            return "placeholders differ in form '\(unit.form)': missing \(missing), extra \(extra)"
        }
    }

    static func placeholders(in text: String) -> Set<String> {
        Set(placeholder.matchedTexts(in: text).map { match in
            // `%1$@` and `%@` name the same kind of argument.
            match.replacing(position, with: "%")
        })
    }

    static func unknownKeys(in sources: [SourceFile], known: Set<String>) -> [Finding] {
        sources.flatMap { file in
            file.text.split(separator: "\n", omittingEmptySubsequences: false).enumerated().flatMap { index, line in
                line.matches(of: lookup).map(\.output.1).filter { !known.contains(String($0)) }.map { key in
                    Finding(location: "\(file.path):\(index + 1)", key: String(key), message: "no catalog has this key")
                }
            }
        }
    }

    /// The same pattern as `PseudoLocale.placeholder` in CityUI; keep the two in step.
    nonisolated(unsafe) static let placeholder = /%(?:\d+\$)?[-+ 0#]*\d*(?:\.\d+)?(?:ll|l|h)?[@dDuUxXoOfeEgGcCsSp%]|\{[A-Za-z]+\}/
    nonisolated(unsafe) static let position = /^%\d+\$/
    /// der, die, das, den, dem, des; ein, eine, einen, einem, einer, eines; and the kein- forms.
    nonisolated(unsafe) static let articleBeforePlaceholder =
        /(?i)\b(?:d(?:er|ie|as|en|em|es)|k?ein(?:e[nmrs]?)?)\s+(?:\{[A-Za-z]+\}|%(?:\d+\$)?@)/
    /// The call sites that name a catalog key (design D3). Every SwiftUI
    /// helper takes its key with the `l10n:` label so this one pattern finds it.
    nonisolated(unsafe) static let lookup = /(?:GameText\.string|l10n:)\s*\(?\s*"([^"\\]+)"/
}

extension Regex {
    func matchedTexts(in text: String) -> [String] {
        text.matches(of: self).map { String(text[$0.range]) }
    }

    func firstMatchedText(in text: String) -> String? {
        text.firstMatch(of: self).map { String(text[$0.range]) }
    }
}

extension String {
    func containsWholeWord(_ word: String) -> Bool {
        var start = startIndex
        while let range = range(of: word, range: start ..< endIndex) {
            let before = range.lowerBound == startIndex ? nil : self[index(before: range.lowerBound)]
            let after = range.upperBound == endIndex ? nil : self[range.upperBound]
            if !(before?.isLetter ?? false), !(after?.isLetter ?? false) { return true }
            start = range.upperBound
        }
        return false
    }
}
