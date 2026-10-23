#if canImport(ImageIO)
import Foundation

/// What the content gate needs from `Sprites.style/catalog/<id>.md`: each brief's `source`, and the
/// edge a declared moving part sweeps. Entries with `source = "isokit"` or `"svg"` have migrated to
/// the art kit, and the kit-only rules (scale twins, walker size) apply to them.
public struct GateCatalog: Sendable {
    public enum Edge: String, Sendable {
        case left, right, top
    }

    public struct Entry: Equatable, Sendable {
        public let id: String
        public let source: String
        public let sweptEdge: Edge?

        public init(id: String, source: String, sweptEdge: Edge? = nil) {
            self.id = id
            self.source = source
            self.sweptEdge = sweptEdge
        }

        public var isMigrated: Bool {
            source == "isokit" || source == "svg"
        }
    }

    public let entries: [String: Entry]
    /// Sprite stem → owning brief, from each brief's `## Sprites` list (`- `name``).
    let owners: [String: String]

    public init(entries: [Entry], spriteNames: [String: [String]] = [:]) {
        self.entries = Dictionary(entries.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        var owners: [String: String] = [:]
        for (id, names) in spriteNames {
            for name in names {
                owners[name] = id
            }
        }
        self.owners = owners
    }

    /// Every sprite name a migrated brief lists in its Sprites section, sorted.
    public var migratedSpriteNames: [String] {
        owners.filter { entries[$0.value]?.isMigrated == true }.keys.sorted()
    }

    /// Sprite names more than one brief lists in its Sprites section.
    public struct DuplicateSpriteNames: Error, Equatable, CustomStringConvertible {
        public let names: [String]

        public var description: String {
            "sprites listed by more than one catalog brief: \(names.joined(separator: ", "))"
        }
    }

    /// A brief whose sprite list cannot be read.
    public struct UnreadableBrief: Error, Equatable, CustomStringConvertible {
        public let id: String
        public let reason: String

        public var description: String {
            "catalog brief \(id): \(reason)"
        }
    }

    /// The catalog under `<resources>/Sprites.style/catalog`, or an empty one when there is none.
    /// Throws `DuplicateSpriteNames` when two briefs claim the same sprite, and `UnreadableBrief` when a
    /// brief lists no sprite.
    public static func load(resourcesRoot: URL) throws -> GateCatalog {
        let directory = resourcesRoot.appendingPathComponent("Sprites.style/catalog")
        guard FileManager.default.fileExists(atPath: directory.path) else { return GateCatalog(entries: []) }
        let files = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "md" }
        var entries: [Entry] = [], sprites: [String: [String]] = [:]
        for file in files {
            let id = file.deletingPathExtension().lastPathComponent
            let markdown = try String(contentsOf: file, encoding: .utf8)
            entries.append(parse(id: id, markdown: markdown))
            sprites[id] = try spriteNames(in: markdown, id: id)
        }
        var claims: [String: Int] = [:]
        // A brief may list a sprite twice (two cells for one frame); only claims by different briefs clash.
        for name in sprites.values.flatMap(Set.init) {
            claims[name, default: 0] += 1
        }
        let duplicates = claims.filter { $0.value > 1 }.keys.sorted()
        guard duplicates.isEmpty else { throw DuplicateSpriteNames(names: duplicates) }
        return GateCatalog(entries: entries, spriteNames: sprites)
    }

    /// Sprite names from the brief's `## Sprites` section (`- \`name\`` lines). A brief with no Sprites
    /// section, an empty one, or a name outside `[a-z0-9-]` is an error, so no brief drops out unnoticed.
    static func spriteNames(in markdown: String, id: String) throws -> [String] {
        let lines = markdown.components(separatedBy: "\n").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        guard let start = lines.firstIndex(of: "## Sprites") else { throw UnreadableBrief(id: id, reason: "no `## Sprites` section") }
        let names = try lines[(start + 1)...].prefix { !$0.hasPrefix("## ") }.compactMap { line -> String? in
            guard line.hasPrefix("- ") else { return nil }
            guard let match = line.firstMatch(of: #/^- `([a-z0-9-]+)`/#) else {
                throw UnreadableBrief(id: id, reason: "sprite line is not - `name`: \(line)")
            }
            return String(match.1)
        }
        guard !names.isEmpty else { throw UnreadableBrief(id: id, reason: "its Sprites section lists no sprite") }
        return names
    }

    static func parse(id: String, markdown: String) -> Entry {
        var source = ""
        var edge: Edge?
        let lines = markdown.components(separatedBy: "\n")
        if lines.first == "---", let end = lines.dropFirst().firstIndex(of: "---") {
            for line in lines[1 ..< end] {
                let parts = line.split(separator: "=", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespaces) }
                if parts.count == 2, parts[0] == "source" {
                    source = parts[1].trimmingCharacters(in: CharacterSet(charactersIn: "\""))
                }
            }
        }
        // `- Moving part: sails, 4 frames, sweeps right` in the Recipe section.
        for line in lines where line.hasPrefix("- Moving part:") {
            if let word = line.components(separatedBy: "sweeps ").last?.trimmingCharacters(in: .whitespaces) {
                edge = Edge(rawValue: word)
            }
        }
        return Entry(id: id, source: source, sweptEdge: edge)
    }

    /// The brief a sprite belongs to: the brief whose Sprites section lists it, else the longest catalog id that
    /// is the sprite's stem or a `-`-separated prefix of it. The Sprites list comes first because prefixes
    /// mislead: `building-house-tier3-renaissance` belongs to `building-house-renaissance`.
    public func entry(forSprite fileName: String) -> Entry? {
        let stem = SpriteFile(fileName).stem
        if let owner = owners[stem] { return entries[owner] }
        var candidate = stem
        while true {
            if let entry = entries[candidate] { return entry }
            guard let dash = candidate.lastIndex(of: "-") else { return nil }
            candidate = String(candidate[..<dash])
        }
    }
}

/// A sprite file name split into its stem and scale: `building-house@2x.png` → (`building-house`, 2).
public struct SpriteFile: Equatable, Sendable {
    public let stem: String
    public let scale: Int

    public init(_ fileName: String) {
        let base = (fileName as NSString).deletingPathExtension
        let marker = base.hasSuffix("x") ? base.range(of: "@", options: .backwards) : nil
        let parsed = marker.flatMap { Int(base[$0.upperBound...].dropLast()) }
        if let marker, let parsed {
            stem = String(base[..<marker.lowerBound])
            scale = parsed
        } else {
            stem = base
            scale = 1
        }
    }

    /// The file name of `stem` at this file's scale.
    public func sibling(_ stem: String) -> String {
        scale == 1 ? "\(stem).png" : "\(stem)@\(scale)x.png"
    }
}
#endif
