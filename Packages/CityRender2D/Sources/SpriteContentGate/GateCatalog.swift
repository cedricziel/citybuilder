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
    /// Sprite stem → owning brief, from each brief's Sheet list (`- (r, c): `name``).
    let owners: [String: String]

    public init(entries: [Entry], sheetNames: [String: [String]] = [:]) {
        self.entries = Dictionary(entries.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        var owners: [String: String] = [:]
        for (id, names) in sheetNames {
            for name in names {
                owners[name] = id
            }
        }
        self.owners = owners
    }

    /// The catalog under `<resources>/Sprites.style/catalog`, or an empty one when there is none.
    public static func load(resourcesRoot: URL) throws -> GateCatalog {
        let directory = resourcesRoot.appendingPathComponent("Sprites.style/catalog")
        guard FileManager.default.fileExists(atPath: directory.path) else { return GateCatalog(entries: []) }
        let files = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "md" }
        var entries: [Entry] = [], sheets: [String: [String]] = [:]
        for file in files {
            let id = file.deletingPathExtension().lastPathComponent
            let markdown = try String(contentsOf: file, encoding: .utf8)
            entries.append(parse(id: id, markdown: markdown))
            sheets[id] = sheetNames(in: markdown)
        }
        return GateCatalog(entries: entries, sheetNames: sheets)
    }

    static func sheetNames(in markdown: String) -> [String] {
        markdown.components(separatedBy: "\n").compactMap { line in
            guard line.hasPrefix("- ("), let open = line.firstIndex(of: "`") else { return nil }
            let rest = line[line.index(after: open)...]
            return rest.firstIndex(of: "`").map { String(rest[..<$0]) }
        }
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

    /// The brief a sprite belongs to: the brief whose Sheet lists it, else the longest catalog id that
    /// is the sprite's stem or a `-`-separated prefix of it. The Sheet comes first because prefixes
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
