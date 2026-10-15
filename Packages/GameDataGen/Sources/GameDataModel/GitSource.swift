import Foundation

/// The manifest and packs as committed at a git revision, read through
/// `git show`. `dataDirectory` is the game-data directory in a working
/// tree of the repository; its path inside the repository is asked from
/// git, so the source works from any current directory.
public struct GitSource: PackSource {
    public let revision: String
    public let dataDirectory: URL

    public init(revision: String, dataDirectory: URL) {
        self.revision = revision
        self.dataDirectory = dataDirectory
    }

    /// Why the revision can't be read, in git's words; nil when it can.
    public func problem() -> String? {
        let prefix = git(["rev-parse", "--show-prefix"])
        if prefix.status != 0 { return prefix.error }
        let commit = git(["rev-parse", "--verify", "\(revision)^{commit}"])
        return commit.status == 0 ? nil : commit.error
    }

    public func read(_ path: String) -> String? {
        guard let prefix = repositoryPath() else { return nil }
        let result = git(["show", "\(revision):\(prefix)\(path)"])
        return result.status == 0 ? result.output : nil
    }

    public func packFiles() -> [String] {
        guard let prefix = repositoryPath() else { return [] }
        let listing = git(["ls-tree", "-r", "--full-name", "--name-only", revision, "--", "packs"])
        guard listing.status == 0 else { return [] }
        return listing.output.split(separator: "\n").map(String.init)
            .filter { $0.hasPrefix(prefix) && $0.hasSuffix(".yaml") }
            .map { String($0.dropFirst(prefix.count)) }
            .sorted()
    }

    /// The data directory's path from the repository root, with a
    /// trailing slash.
    private func repositoryPath() -> String? {
        let result = git(["rev-parse", "--show-prefix"])
        guard result.status == 0 else { return nil }
        return result.output.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private struct GitResult {
        var status: Int32
        var output: String
        var error: String
    }

    private func git(_ arguments: [String]) -> GitResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["git"] + arguments
        process.currentDirectoryURL = dataDirectory
        let output = Pipe(), error = Pipe()
        process.standardOutput = output
        process.standardError = error
        do {
            try process.run()
        } catch {
            return GitResult(status: -1, output: "", error: "cannot run git: \(error)")
        }
        // These commands write at most a line or two to stderr, far below
        // a pipe's buffer, so reading stdout first can't stall git.
        let outputData = output.fileHandleForReading.readDataToEndOfFile()
        let errorData = error.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        let text = { (data: Data) in String(bytes: data, encoding: .utf8) ?? "" }
        return GitResult(
            status: process.terminationStatus, output: text(outputData),
            error: text(errorData).trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }
}
