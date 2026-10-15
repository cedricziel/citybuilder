import Foundation

/// One `Resources/Sprites.style/catalog/<id>.md` brief: its id, `source`, and the sprite names it declares.
public struct CatalogEntry: Equatable {
    public let id: String
    public let source: String
    /// Sprite names listed in the brief (`- (r, c): \`name\`` lines), in file order.
    public let spriteNames: [String]
    /// `- Key: value` lines of the brief's `## Recipe` section.
    public let recipeFacts: [String: String]

    public init(id: String, source: String, spriteNames: [String] = [], recipeFacts: [String: String] = [:]) {
        self.id = id
        self.source = source
        self.spriteNames = spriteNames
        self.recipeFacts = recipeFacts
    }

    static func recipeFacts(fromMarkdown text: String) -> [String: String] {
        let lines = text.components(separatedBy: "\n")
        guard let start = lines.firstIndex(of: "## Recipe") else { return [:] }
        var facts: [String: String] = [:]
        for line in lines[(start + 1)...].prefix(while: { !$0.hasPrefix("## ") }) where line.hasPrefix("- ") {
            let parts = line.dropFirst(2).split(separator: ":", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespaces) }
            if parts.count == 2 { facts[parts[0]] = parts[1] }
        }
        return facts
    }

    /// Migrated entries are rendered by the new pipeline; everything else keeps its committed PNGs.
    public var isIsoKit: Bool {
        source == "isokit"
    }

    public var isSVG: Bool {
        source == "svg"
    }

    /// Reads `source = "<value>"` from the `---` front matter, or "" when there is none.
    static func source(fromMarkdown text: String) -> String {
        let lines = text.components(separatedBy: "\n")
        guard lines.first?.trimmingCharacters(in: .whitespaces) == "---" else { return "" }
        for line in lines.dropFirst() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed == "---" { break }
            let parts = trimmed.split(separator: "=", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespaces) }
            if parts.count == 2, parts[0] == "source" {
                return parts[1].trimmingCharacters(in: CharacterSet(charactersIn: "\""))
            }
        }
        return ""
    }

    /// Sprite names from `- (row, col): \`name\`` lines; spare cells have no name and are skipped.
    static func spriteNames(fromMarkdown text: String) -> [String] {
        let pattern = #"^- \(\d+, *\d+\): `([a-z0-9-]+)`"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.anchorsMatchLines]) else { return [] }
        let range = NSRange(text.startIndex..., in: text)
        return regex.matches(in: text, range: range).compactMap { match in
            Range(match.range(at: 1), in: text).map { String(text[$0]) }
        }
    }
}

public struct Catalog {
    public let entries: [CatalogEntry]

    public init(entries: [CatalogEntry]) {
        self.entries = entries
    }

    public static func load(directory: URL) throws -> Catalog {
        let files = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "md" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
        let entries = try files.map { file in
            let text = try String(contentsOf: file, encoding: .utf8)
            return CatalogEntry(
                id: file.deletingPathExtension().lastPathComponent,
                source: CatalogEntry.source(fromMarkdown: text),
                spriteNames: CatalogEntry.spriteNames(fromMarkdown: text),
                recipeFacts: CatalogEntry.recipeFacts(fromMarkdown: text)
            )
        }
        return Catalog(entries: entries)
    }

    public func entry(_ id: String) -> CatalogEntry? {
        entries.first { $0.id == id }
    }
}

/// Recipes and catalog briefs must agree for every migrated entry.
public enum RecipeRegistry {
    public static func mismatches(recipes: [Recipe], catalog: Catalog) -> [String] {
        var problems: [String] = []
        for entry in catalog.entries where entry.isIsoKit {
            let owned = recipes.filter { $0.entry == entry.id }
            guard !owned.isEmpty else {
                problems.append("\(entry.id) declares source = \"isokit\" but has no IsoKit recipe")
                continue
            }
            let rendered = Set(owned.flatMap(\.spriteNames)), declared = Set(entry.spriteNames)
            if !declared.isEmpty, rendered != declared {
                let missing = declared.subtracting(rendered).sorted(), extra = rendered.subtracting(declared).sorted()
                problems.append("\(entry.id) sprite names differ from its brief: missing \(missing), extra \(extra)")
            }
        }
        for entry in catalog.entries where entry.isIsoKit {
            if let main = recipes.first(where: { $0.id == entry.id }) {
                problems += factMismatches(main, entry)
            }
        }
        for recipe in recipes where catalog.entry(recipe.entry) == nil {
            problems.append("recipe \(recipe.id) has no catalog entry")
        }
        return problems
    }
}

extension RecipeRegistry {
    /// The brief's `Recipe` numbers must match the recipe it names.
    static func factMismatches(_ recipe: Recipe, _ entry: CatalogEntry) -> [String] {
        var problems: [String] = []
        let checks: [(String, Int)] = [
            ("Construction stages", recipe.constructionFrames),
            ("Operational frames", recipe.operationalFrames)
        ]
        for (key, actual) in checks {
            if let stated = entry.recipeFacts[key], Int(stated) != actual {
                problems.append("\(entry.id): brief says \(key) \(stated), recipe has \(actual)")
            }
        }
        let statedPart = entry.recipeFacts["Moving part"]?.split(separator: ",").first.map(String.init)
        if statedPart != recipe.moving?.name {
            problems.append("\(entry.id): brief names moving part \(statedPart ?? "none"), recipe has \(recipe.moving?.name ?? "none")")
        }
        return problems
    }
}

/// Which recipes `isokit render` touches: only those whose catalog entry has migrated.
public enum RenderSelection {
    public static func recipes(_ recipes: [Recipe], migratedIn catalog: Catalog) -> [Recipe] {
        recipes.filter { catalog.entry($0.entry)?.isIsoKit == true }
    }
}
