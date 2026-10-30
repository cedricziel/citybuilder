import Foundation

/// What the check reads from a checkout: every `.xcstrings` and Swift file
/// under `Packages/*/Sources` and `Apps`, and the glossary.
public struct Repository: Sendable {
    public let catalogs: [Catalog]
    public let sources: [SourceFile]
    public let glossary: Glossary

    public init(root: URL) throws {
        let packages = (try? FileManager.default.contentsOfDirectory(atPath: root.appendingPathComponent("Packages").path)) ?? []
        let directories = packages.sorted().map { "Packages/\($0)/Sources" } + ["Apps"]
        let files = directories.flatMap { Self.files(under: root.appendingPathComponent($0)) }
        let relative = { (url: URL) in String(url.path.dropFirst(root.path.count + 1)) }
        catalogs = try files.filter { $0.pathExtension == "xcstrings" }.map {
            try Catalog(name: relative($0), json: Data(contentsOf: $0))
        }
        sources = try files.filter { $0.pathExtension == "swift" }.map {
            try SourceFile(path: relative($0), text: String(contentsOf: $0, encoding: .utf8))
        }
        let glossaryURL = root.appendingPathComponent("Tools/L10nCheck/glossary.json")
        glossary = try JSONDecoder().decode(Glossary.self, from: Data(contentsOf: glossaryURL))
    }

    private static func files(under directory: URL) -> [URL] {
        let enumerator = FileManager.default.enumerator(
            at: directory, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles, .skipsPackageDescendants]
        )
        return (enumerator?.allObjects as? [URL] ?? []).sorted { $0.path < $1.path }
    }
}
