import CityCore
import Foundation

// Cross-platform determinism gate fixture (spec
// fixed-point-math, Requirement: Cross-platform determinism gate).
//
// Builds the standard archipelago world (M6 generator — pure
// integer math, no IEEE-754 drift) and runs it for a configurable
// number of ticks before JSON-encoding the post-run World to
// stdout. CI runs this on macOS and Linux Swift toolchains and
// diffs the two outputs byte-for-byte.
//
// Usage:
//   swift run DeterminismFixture          # default 6000 ticks (10 min sim)
//   swift run DeterminismFixture 36000    # 60-minute drift check (M10)

let argv = CommandLine.arguments
let tickCount: Int = argv.count >= 2 ? Int(argv[1]) ?? 6000 : 6000

var world = World.newGame(layout: .archipelago, seed: 0xC17B)

for _ in 0 ..< tickCount {
    _ = world.tick()
}

let encoder = JSONEncoder()
encoder.outputFormatting = [.sortedKeys]
let data = try encoder.encode(world)
FileHandle.standardOutput.write(data)
FileHandle.standardOutput.write(Data([0x0A]))
