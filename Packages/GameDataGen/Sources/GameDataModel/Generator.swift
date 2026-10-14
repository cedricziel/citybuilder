import Foundation

public enum Generator {
    /// Loads and validates the game data, then writes the generated Swift
    /// and returns the written file names. Writes nothing when validation
    /// fails.
    public static func generate(dataDirectory: URL, outputDirectory: URL) -> Result<[String], GameDataErrors> {
        GameDataLoader.load(from: DirectorySource(root: dataDirectory)).flatMap { data in
            let files = SwiftEmitter.emit(data)
            do {
                try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
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
}
