import Foundation

/// Where the manifest and packs are read from. Paths are relative to the
/// game-data root, e.g. `index.yaml` and `packs/core.yaml`.
public protocol PackSource {
    func read(_ path: String) -> String?
    /// Every `.yaml` file under `packs/`, sorted.
    func packFiles() -> [String]
}

public struct InMemorySource: PackSource {
    public var files: [String: String]

    public init(files: [String: String]) {
        self.files = files
    }

    public func read(_ path: String) -> String? {
        files[path]
    }

    public func packFiles() -> [String] {
        files.keys.filter { $0.hasPrefix("packs/") && $0.hasSuffix(".yaml") }.sorted()
    }
}

public struct DirectorySource: PackSource {
    public let root: URL

    public init(root: URL) {
        self.root = root
    }

    public func read(_ path: String) -> String? {
        try? String(contentsOf: root.appendingPathComponent(path), encoding: .utf8)
    }

    public func packFiles() -> [String] {
        let packs = root.appendingPathComponent("packs").path
        let files = FileManager.default.enumerator(atPath: packs)?.compactMap { $0 as? String } ?? []
        return files.filter { $0.hasSuffix(".yaml") }.map { "packs/" + $0 }.sorted()
    }
}
