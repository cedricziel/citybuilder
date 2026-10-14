import Foundation
import GameDataModel

/// A new, empty directory under the temporary directory.
func scratch() throws -> URL {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent("gamedata-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}

func write(_ source: InMemorySource, to root: URL) throws {
    for (path, text) in source.files {
        let file = root.appendingPathComponent(path)
        try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        try text.write(to: file, atomically: true, encoding: .utf8)
    }
}

func contents(of directory: URL) throws -> [String: Data] {
    let names = try FileManager.default.contentsOfDirectory(atPath: directory.path)
    return try Dictionary(uniqueKeysWithValues: names.map { name in
        try (name, Data(contentsOf: directory.appendingPathComponent(name)))
    })
}
