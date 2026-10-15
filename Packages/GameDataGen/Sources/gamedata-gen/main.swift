import Foundation
import GameDataModel

let usage = """
usage: gamedata-gen generate [--check] [--data <dir>] [--out <dir>] [--namespace <name>]
       gamedata-gen diff <old-ref> [<new-ref>] [--data <dir>]
       gamedata-gen hook pre|post   (Claude Code hook JSON on stdin)

Defaults, relative to the repository root:
  --data Packages/CityCore/GameData
  --out  Packages/CityCore/Sources/CityCore/Generated

--check writes nothing and fails when the output directory is not what
        generate would write.
--namespace nests every generated type in `enum <name>`, in one file.
diff    lists changed values, added and removed items between two git
        revisions; without <new-ref>, against the working tree.
hook    exits 2 to block a hand edit of the generated Swift (pre) or to
        report a pack edit that no longer validates (post); else 0.
"""

func fail(_ message: String, status: Int32) -> Never {
    FileHandle.standardError.write(Data((message + "\n").utf8))
    exit(status)
}

/// Splits `--name value` pairs off `arguments`, keeping the rest in order.
func options(_ arguments: [String], allowed: [String], defaults: [String: String]) -> ([String], [String: String]) {
    var options = defaults, positional: [String] = []
    var index = 0
    while index < arguments.count {
        let argument = arguments[index]
        if argument.hasPrefix("--") {
            guard allowed.contains(argument), index + 1 < arguments.count else { fail(usage, status: 64) }
            options[argument] = arguments[index + 1]
            index += 2
        } else {
            positional.append(argument)
            index += 1
        }
    }
    return (positional, options)
}

let defaultData = "Packages/CityCore/GameData"
var arguments = Array(CommandLine.arguments.dropFirst())
let command = arguments.isEmpty ? "" : arguments.removeFirst()

switch command {
case "generate":
    let checkOnly = arguments.contains("--check")
    arguments.removeAll { $0 == "--check" }
    let (positional, values) = options(
        arguments, allowed: ["--data", "--out", "--namespace"],
        defaults: ["--data": defaultData, "--out": "Packages/CityCore/Sources/CityCore/Generated"]
    )
    guard positional.isEmpty else { fail(usage, status: 64) }
    let data = URL(fileURLWithPath: values["--data"]!)
    let out = URL(fileURLWithPath: values["--out"]!)
    let namespace = values["--namespace"]
    if checkOnly {
        switch Generator.check(dataDirectory: data, outputDirectory: out, namespace: namespace) {
        case let .success(drift) where drift.isEmpty:
            print("generated files in \(out.path) are up to date")
        case let .success(drift):
            fail((drift + ["Run `make gamedata` and commit the result."]).joined(separator: "\n"), status: 1)
        case let .failure(errors):
            fail(errors.description, status: 1)
        }
    } else {
        switch Generator.generate(dataDirectory: data, outputDirectory: out, namespace: namespace) {
        case let .success(files):
            print("wrote \(files.count) files to \(out.path)")
        case let .failure(errors):
            fail(errors.description, status: 1)
        }
    }

case "diff":
    let (revisions, values) = options(arguments, allowed: ["--data"], defaults: ["--data": defaultData])
    guard (1 ... 2).contains(revisions.count) else { fail(usage, status: 64) }
    let directory = values["--data"]!
    let here = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    let old = GitSource(repository: here, revision: revisions[0], dataDirectory: directory)
    let new: PackSource = revisions.count == 2
        ? GitSource(repository: here, revision: revisions[1], dataDirectory: directory)
        : DirectorySource(root: URL(fileURLWithPath: directory))
    switch ContentDiff.diff(old: old, new: new) {
    case let .success(lines):
        lines.forEach { print($0) }
    case let .failure(errors):
        fail(errors.description, status: 1)
    }

case "hook":
    guard arguments.count == 1, let phase = GameDataHook.Phase(rawValue: arguments[0]) else { fail(usage, status: 64) }
    let outcome = GameDataHook.run(phase, input: FileHandle.standardInput.readDataToEndOfFile())
    if !outcome.message.isEmpty { FileHandle.standardError.write(Data((outcome.message + "\n").utf8)) }
    exit(outcome.status)

default:
    fail(usage, status: 64)
}
