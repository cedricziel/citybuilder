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

// The archipelago game, plus a short grain chain whose producers send
// grain and flour straight to their consumers (visible-distribution
// milestone 1), and a long haul that storage covers by handcart
// (milestone 3), which the archipelago's opening never does.
var world = World.newGame(layout: .archipelago, seed: 0xC17B)
var chain = World.chainFixture()
var haul = World.haulFixture()

for _ in 0 ..< tickCount {
    _ = world.tick()
    _ = chain.tick()
    _ = haul.tick()
}

struct Fixture: Encodable {
    let world: World
    let chain: World
    let haul: World
}

let encoder = JSONEncoder()
encoder.outputFormatting = [.sortedKeys]
let data = try encoder.encode(Fixture(world: world, chain: chain, haul: haul))
FileHandle.standardOutput.write(data)
FileHandle.standardOutput.write(Data([0x0A]))
