import Foundation

/// Abstracts atomic file writes so tests can inject failures (the
/// "Crash mid-save preserves previous save" scenario uses a faulting
/// writer).
public protocol FileWriter: Sendable {
    func write(_ data: Data, to url: URL) throws
    func read(from url: URL) throws -> Data
    func remove(at url: URL) throws
    func exists(at url: URL) -> Bool
}

public struct AtomicDiskWriter: FileWriter, Sendable {
    public init() {}

    public func write(_ data: Data, to url: URL) throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let tmp = url.appendingPathExtension("tmp")
        try data.write(to: tmp, options: [.atomic])
        if FileManager.default.fileExists(atPath: url.path) {
            _ = try? FileManager.default.removeItem(at: url)
        }
        try FileManager.default.moveItem(at: tmp, to: url)
    }

    public func read(from url: URL) throws -> Data {
        try Data(contentsOf: url)
    }

    public func remove(at url: URL) throws {
        try FileManager.default.removeItem(at: url)
    }

    public func exists(at url: URL) -> Bool {
        FileManager.default.fileExists(atPath: url.path)
    }
}
