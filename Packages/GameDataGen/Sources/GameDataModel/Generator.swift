import Foundation

public enum Generator {
    /// Loads and validates the game data, then writes the generated Swift
    /// and, given a `catalogFile`, the pack-text catalog merged into it.
    /// Returns the written Swift file names. Writes nothing when validation
    /// fails. A `namespace` is passed on to `SwiftEmitter.emit`.
    public static func generate(
        dataDirectory: URL, outputDirectory: URL, catalogFile: URL? = nil, namespace: String? = nil
    ) -> Result<[String], GameDataErrors> {
        load(dataDirectory).flatMap { data in
            let files = SwiftEmitter.emit(data, namespace: namespace)
            do {
                if let catalogFile {
                    let catalog = try CatalogEmitter.catalog(data, merging: try? Data(contentsOf: catalogFile))
                    try Data(catalog.utf8).write(to: catalogFile, options: .atomic)
                }
                try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
                for name in generatedFiles(in: outputDirectory) where files[name] == nil {
                    try FileManager.default.removeItem(at: outputDirectory.appendingPathComponent(name))
                }
                for (name, text) in files {
                    try Data(text.utf8).write(to: outputDirectory.appendingPathComponent(name), options: .atomic)
                }
            } catch {
                let failure = Diagnostic(origin: Origin(file: outputDirectory.path), message: "cannot write: \(error)")
                return .failure(GameDataErrors(diagnostics: [failure]))
            }
            return .success(files.keys.sorted())
        }
    }

    /// Compares what `generate` would write with the output directory and
    /// the catalog, and writes nothing. Returns one line per generated file
    /// that differs, is missing, or is no longer generated; empty when up
    /// to date.
    public static func check(
        dataDirectory: URL, outputDirectory: URL, catalogFile: URL? = nil, namespace: String? = nil
    ) -> Result<[String], GameDataErrors> {
        load(dataDirectory).map { data in
            let files = SwiftEmitter.emit(data, namespace: namespace)
            var drift = files.compactMap { name, text -> String? in
                guard let committed = try? Data(contentsOf: outputDirectory.appendingPathComponent(name)) else {
                    return "\(name) is missing"
                }
                return committed == Data(text.utf8) ? nil : "\(name) differs"
            }
            if let catalogFile {
                let name = catalogFile.lastPathComponent
                if let committed = try? Data(contentsOf: catalogFile) {
                    let expected = try? CatalogEmitter.catalog(data, merging: committed)
                    if expected.map({ Data($0.utf8) }) != committed { drift.append("\(name) differs") }
                } else {
                    drift.append("\(name) is missing")
                }
            }
            let leftovers = generatedFiles(in: outputDirectory).filter { files[$0] == nil }.map { "\($0) is no longer generated" }
            return (drift + leftovers).sorted()
        }
    }

    private static func load(_ dataDirectory: URL) -> Result<GameData, GameDataErrors> {
        GameDataLoader.load(from: DirectorySource(root: dataDirectory))
    }

    /// Swift files in `directory` that carry the generated-file banner.
    private static func generatedFiles(in directory: URL) -> [String] {
        let names = (try? FileManager.default.contentsOfDirectory(atPath: directory.path)) ?? []
        return names.filter { name in
            guard name.hasSuffix(".swift"),
                  let text = try? String(contentsOf: directory.appendingPathComponent(name), encoding: .utf8)
            else { return false }
            return text.hasPrefix(SwiftEmitter.marker)
        }
    }
}
