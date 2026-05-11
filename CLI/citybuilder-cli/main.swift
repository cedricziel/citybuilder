import CityCore
import Foundation

// Minimal argument parser. Supports:
//   citybuilder-cli --ticks N
//   citybuilder-cli --save PATH --ticks N
//   citybuilder-cli --save PATH --ticks N --events-out events.json
//
// No third-party flag library so the CLI stays dependency-free and easy to
// run from CI / a Swift package script. ArgumentParser would be cleaner once
// the CLI grows beyond a few flags.

struct ParsedArgs {
    let save: String?
    let ticks: Int
    let eventsOut: String?
}

func parseArgs(_ argv: [String]) -> ParsedArgs {
    var save: String?
    var ticks = 100
    var eventsOut: String?
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
        case "--events-out":
            guard index + 1 < argv.count else {
                FileHandle.standardError.write(Data("citybuilder-cli: --events-out requires a path\n".utf8))
                exit(2)
            }
            eventsOut = argv[index + 1]
            index += 2
        case "--help", "-h":
            print("usage: citybuilder-cli [--save PATH] [--ticks N] [--events-out FILE]")
            exit(0)
        default:
            FileHandle.standardError.write(Data("citybuilder-cli: unknown argument '\(token)'\n".utf8))
            exit(2)
        }
    }
    return ParsedArgs(save: save, ticks: ticks, eventsOut: eventsOut)
}

let parsed = parseArgs(CommandLine.arguments)

do {
    let summary: HeadlessRunner.Summary
    if let eventsOut = parsed.eventsOut {
        let result = try HeadlessRunner.runCollectingEvents(
            loadFrom: parsed.save,
            ticks: parsed.ticks
        )
        summary = result.summary
        let json = try WorldEventJSON.encode(result.events)
        try json.write(to: URL(fileURLWithPath: eventsOut))
    } else {
        summary = try HeadlessRunner.run(loadFrom: parsed.save, ticks: parsed.ticks)
    }
    print("citybuilder-cli summary:")
    print("  source       : \(parsed.save ?? "(fresh new game)")")
    print("  ticks        : \(summary.tickCount)")
    print("  simulated ms : \(summary.simulatedTime.nanoseconds / 1_000_000)")
    print("  map size     : \(summary.mapWidth) × \(summary.mapHeight)")
    if let eventsOut = parsed.eventsOut {
        print("  events       : \(eventsOut)")
    }
} catch {
    FileHandle.standardError.write(Data("citybuilder-cli: \(error)\n".utf8))
    exit(1)
}
