import Foundation
import GameDataModel

let usage = """
usage: gamedata-gen generate [--check] [--data <dir>] [--out <dir>] [--namespace <name>]

Defaults, relative to the repository root:
  --data Packages/CityCore/GameData
  --out  Packages/CityCore/Sources/CityCore/Generated

--check writes nothing and fails when the output directory is not what
        generate would write.
--namespace nests every generated type in `enum <name>`, in one file.
"""

func fail(_ message: String, status: Int32) -> Never {
    FileHandle.standardError.write(Data((message + "\n").utf8))
    exit(status)
}

var arguments = Array(CommandLine.arguments.dropFirst())
let checkOnly = arguments.contains("--check")
arguments.removeAll { $0 == "--check" }
guard arguments.first == "generate", !arguments.count.isMultiple(of: 2) else { fail(usage, status: 64) }

var options = ["--data": "Packages/CityCore/GameData", "--out": "Packages/CityCore/Sources/CityCore/Generated"]
for index in stride(from: 1, to: arguments.count, by: 2) {
    guard ["--data", "--out", "--namespace"].contains(arguments[index]) else { fail(usage, status: 64) }
    options[arguments[index]] = arguments[index + 1]
}

let data = URL(fileURLWithPath: options["--data"]!)
let out = URL(fileURLWithPath: options["--out"]!)
let namespace = options["--namespace"]

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
