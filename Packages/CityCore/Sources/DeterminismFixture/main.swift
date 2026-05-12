import CityCore
import Foundation

// Cross-platform determinism gate fixture (spec
// fixed-point-math, Requirement: Cross-platform determinism gate).
//
// Builds a deterministic World seeded for the determinism scenario,
// runs 6000 ticks, JSON-encodes the post-run World, and prints the
// JSON to stdout. CI runs this on macOS and Linux Swift toolchains
// and diffs the two outputs byte-for-byte.
//
// TODO(M6): switch the fixture to `World.archipelagoFixture(seed:)`
// once `add-archipelago-and-sea` M6 lands. The current single-terrain
// fixture is safe because it bypasses `IslandGenerator`'s Double
// math (which has not been ported to Fixed yet).

let tickCount = 6000

var world = World.fixtureWithTerrain(
    width: 32,
    height: 32,
    fill: .grass,
    seed: 0xC17B
)

for _ in 0 ..< tickCount {
    _ = world.tick()
}

let encoder = JSONEncoder()
encoder.outputFormatting = [.sortedKeys]
let data = try encoder.encode(world)
FileHandle.standardOutput.write(data)
FileHandle.standardOutput.write(Data([0x0A]))
