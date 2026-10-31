import Foundation

/// The `gamedata-gen` command line, kept in the library so tests run the
/// same code paths as the executable.
public enum GameDataCommand {
    public struct Outcome: Equatable, Sendable {
        public var status: Int32
        public var output: String
        public var error: String

        public init(status: Int32, output: String = "", error: String = "") {
            self.status = status
            self.output = output
            self.error = error
        }
    }

    public static let usage = """
    usage: gamedata-gen generate [--check] [--data <dir>] [--out <dir>] [--catalog <file>] [--namespace <name>]
           gamedata-gen diff <old-ref> [<new-ref>] [--data <dir>]
           gamedata-gen hook pre|post   (Claude Code hook JSON on stdin)

    Defaults, relative to the current directory:
      --data Packages/CityCore/GameData
      --out  Packages/CityCore/Sources/CityCore/Generated
      --catalog Packages/CityUI/Sources/CityUI/Resources/GameData.xcstrings

    --check writes nothing and fails when the output directory is not what
            generate would write.
    --catalog is the pack-text String Catalog; generate keeps its other
            languages and marks them for review when the English changes.
    --namespace nests every generated type in `enum <name>`, in one file.
    diff    lists changed values, then added and removed items, between two
            git revisions; without <new-ref>, against the working tree.
    hook    exits 2 to block a hand edit of the generated Swift (pre) or to
            report a pack edit that no longer validates (post); else 0.
    """

    static let defaultData = "Packages/CityCore/GameData"
    static let defaultOut = "Packages/CityCore/Sources/CityCore/Generated"
    static let defaultCatalog = "Packages/CityUI/Sources/CityUI/Resources/GameData.xcstrings"

    public static func run(
        _ arguments: [String], standardInput: () -> Data, currentDirectory: URL
    ) -> Outcome {
        var arguments = arguments
        let command = arguments.isEmpty ? "" : arguments.removeFirst()
        let path = { (value: String) in
            (value.hasPrefix("/") ? URL(fileURLWithPath: value) : currentDirectory.appendingPathComponent(value)).standardizedFileURL
        }
        switch command {
        case "generate":
            let checkOnly = arguments.contains("--check")
            arguments.removeAll { $0 == "--check" }
            guard let (positional, values) = options(
                arguments, allowed: ["--data", "--out", "--catalog", "--namespace"],
                defaults: ["--data": defaultData, "--out": defaultOut, "--catalog": defaultCatalog]
            ), positional.isEmpty
            else { return usageError }
            return generate(
                data: path(values["--data"]!), out: path(values["--out"]!), catalog: path(values["--catalog"]!),
                namespace: values["--namespace"], checkOnly: checkOnly
            )
        case "diff":
            guard let (revisions, values) = options(arguments, allowed: ["--data"], defaults: ["--data": defaultData]),
                  (1 ... 2).contains(revisions.count)
            else { return usageError }
            return diff(revisions: revisions, data: path(values["--data"]!))
        case "hook":
            guard arguments.count == 1, let phase = GameDataHook.Phase(rawValue: arguments[0]) else { return usageError }
            let outcome = GameDataHook.run(phase, input: standardInput())
            return Outcome(status: outcome.status, error: outcome.message.isEmpty ? "" : outcome.message + "\n")
        default:
            return usageError
        }
    }

    private static let usageError = Outcome(status: 64, error: usage + "\n")

    private static func generate(data: URL, out: URL, catalog: URL, namespace: String?, checkOnly: Bool) -> Outcome {
        if checkOnly {
            switch Generator.check(dataDirectory: data, outputDirectory: out, catalogFile: catalog, namespace: namespace) {
            case let .success(drift) where drift.isEmpty:
                return Outcome(status: 0, output: "generated files in \(out.path) are up to date\n")
            case let .success(drift):
                let lines = drift + ["Run `make gamedata` and commit the result."]
                return Outcome(status: 1, error: lines.joined(separator: "\n") + "\n")
            case let .failure(errors):
                return Outcome(status: 1, error: "\(errors)\n")
            }
        }
        switch Generator.generate(dataDirectory: data, outputDirectory: out, catalogFile: catalog, namespace: namespace) {
        case let .success(files):
            return Outcome(status: 0, output: "wrote \(files.count) files to \(out.path)\n")
        case let .failure(errors):
            return Outcome(status: 1, error: "\(errors)\n")
        }
    }

    private static func diff(revisions: [String], data: URL) -> Outcome {
        let old = GitSource(revision: revisions[0], dataDirectory: data)
        let newRevision = revisions.count == 2 ? GitSource(revision: revisions[1], dataDirectory: data) : nil
        for source in [old] + (newRevision.map { [$0] } ?? []) {
            if let problem = source.problem() {
                return Outcome(status: 1, error: "cannot read \(source.revision): \(problem)\n")
            }
        }
        switch ContentDiff.diff(old: old, new: newRevision ?? DirectorySource(root: data) as PackSource) {
        case let .success(lines):
            return Outcome(status: 0, output: lines.map { $0 + "\n" }.joined())
        case let .failure(errors):
            return Outcome(status: 1, error: "\(errors)\n")
        }
    }

    /// Splits `--name value` pairs off `arguments`, keeping the rest in
    /// order; nil when an option is unknown or has no value.
    private static func options(
        _ arguments: [String], allowed: Set<String>, defaults: [String: String]
    ) -> ([String], [String: String])? {
        var options = defaults, positional: [String] = []
        var index = 0
        while index < arguments.count {
            let argument = arguments[index]
            if argument.hasPrefix("--") {
                guard allowed.contains(argument), index + 1 < arguments.count else { return nil }
                options[argument] = arguments[index + 1]
                index += 2
            } else {
                positional.append(argument)
                index += 1
            }
        }
        return (positional, options)
    }
}
