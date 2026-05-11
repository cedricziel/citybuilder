import CityCore
import Foundation

// Minimal argument parser. Supports:
//   citybuilder-cli --ticks N
//   citybuilder-cli --save PATH --ticks N
//
// No third-party flag library so the CLI stays dependency-free and easy to
// run from CI / a Swift package script. ArgumentParser would be cleaner once
// the CLI grows beyond a few flags.

func parseArgs(_ argv: [String]) -> (save: String?, ticks: Int) {
    var save: String?
    var ticks = 100
    var index = 1
    while index < argv.count {
        let token = argv[index]
        switch token {
        case "--save":
            guard index + 1 < argv.count else {
                FileHandle.standardError.write(Data("citybuilder-cli: --save requires a path\n".utf8))
                exit(2)
            }
            save = argv[index + 1]
            index += 2
        case "--ticks":
            guard index + 1 < argv.count, let value = Int(argv[index + 1]) else {
                FileHandle.standardError.write(Data("citybuilder-cli: --ticks requires a non-negative integer\n".utf8))
                exit(2)
            }
            ticks = value
            index += 2
        case "--help", "-h":
            print("usage: citybuilder-cli [--save PATH] [--ticks N]")
            exit(0)
        default:
            FileHandle.standardError.write(Data("citybuilder-cli: unknown argument '\(token)'\n".utf8))
            exit(2)
        }
    }
    return (save, ticks)
}

let parsed = parseArgs(CommandLine.arguments)

do {
    let summary = try HeadlessRunner.run(loadFrom: parsed.save, ticks: parsed.ticks)
    print("citybuilder-cli summary:")
    print("  source       : \(parsed.save ?? "(fresh new game)")")
    print("  ticks        : \(summary.tickCount)")
    print("  simulated ms : \(summary.simulatedTime.nanoseconds / 1_000_000)")
    print("  map size     : \(summary.mapWidth) × \(summary.mapHeight)")
} catch {
    FileHandle.standardError.write(Data("citybuilder-cli: \(error)\n".utf8))
    exit(1)
}
