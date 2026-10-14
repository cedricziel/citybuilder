import Foundation
import GameDataModel

let usage = """
usage: gamedata-gen generate [--data <dir>] [--out <dir>]

Defaults, relative to the repository root:
  --data Packages/CityCore/GameData
  --out  Packages/CityCore/Sources/CityCore/Generated
"""

func fail(_ message: String, status: Int32) -> Never {
    FileHandle.standardError.write(Data((message + "\n").utf8))
    exit(status)
}

let arguments = Array(CommandLine.arguments.dropFirst())
guard arguments.first == "generate", !arguments.count.isMultiple(of: 2) else { fail(usage, status: 64) }

var options = ["--data": "Packages/CityCore/GameData", "--out": "Packages/CityCore/Sources/CityCore/Generated"]
for index in stride(from: 1, to: arguments.count, by: 2) {
    guard options[arguments[index]] != nil else { fail(usage, status: 64) }
    options[arguments[index]] = arguments[index + 1]
}

let data = URL(fileURLWithPath: options["--data"]!)
let out = URL(fileURLWithPath: options["--out"]!)
switch Generator.generate(dataDirectory: data, outputDirectory: out) {
case let .success(files):
    print("wrote \(files.count) files to \(out.path)")
case let .failure(errors):
    fail(errors.description, status: 1)
}
