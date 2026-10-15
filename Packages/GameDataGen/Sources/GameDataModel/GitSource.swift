import Foundation

/// The manifest and packs as committed at a git revision, read through
/// `git show`. `dataDirectory` is relative to `repository`.
public struct GitSource: PackSource {
    public let repository: URL
    public let revision: String
    public let dataDirectory: String

    public init(repository: URL, revision: String, dataDirectory: String) {
        self.repository = repository
        self.revision = revision
        self.dataDirectory = dataDirectory
    }

    public func read(_ path: String) -> String? {
        git(["show", "\(revision):./\(dataDirectory)/\(path)"])
    }

    public func packFiles() -> [String] {
        let prefix = dataDirectory + "/"
        let listing = git(["ls-tree", "-r", "--name-only", revision, "--", prefix + "packs"]) ?? ""
        return listing.split(separator: "\n").map(String.init)
            .filter { $0.hasPrefix(prefix) && $0.hasSuffix(".yaml") }
            .map { String($0.dropFirst(prefix.count)) }
            .sorted()
    }

    /// The command's standard output, or nil when it fails.
    private func git(_ arguments: [String]) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["git"] + arguments
        process.currentDirectoryURL = repository
        let output = Pipe()
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
        } catch {
            return nil
        }
        let data = output.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else { return nil }
        return String(bytes: data, encoding: .utf8)
    }
}
