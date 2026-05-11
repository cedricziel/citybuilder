import Foundation

/// Fixed-island generator. The MVP island is identical across all new games
/// (spec `world-terrain` "Map is identical across launches") so it does not
/// take a seed — the output is a pure function of the constants below.
///
/// Implementation: a deterministic procedural recipe layered over distance
/// from the map center.
///
///   1. Stamp water everywhere outside the island silhouette.
///   2. Stamp beach in a thin ring just inside the silhouette.
///   3. Stamp mountain near the island core.
///   4. Stamp forest in periodic patches across the interior.
///   5. Everything that survived is grass.
///
/// No randomness. No I/O. Byte-stable across platforms and Swift versions.
public enum IslandGenerator {
    public static let width = 96
    public static let height = 96

    private static let centerX = Double(width) / 2.0
    private static let centerY = Double(height) / 2.0
    private static let islandRadius = 40.0 // tiles beyond this = water
    private static let beachWidth = 3.0 // ring of beach inside the shore
    private static let mountainRadius = 12.0 // mountains cluster near center

    public static func generate() -> [TerrainType] {
        var grid: [TerrainType] = Array(repeating: .water, count: width * height)
        for tileY in 0 ..< height {
            for tileX in 0 ..< width {
                grid[tileY * width + tileX] = terrain(atTileX: tileX, tileY: tileY)
            }
        }
        return grid
    }

    private static func terrain(atTileX tileX: Int, tileY: Int) -> TerrainType {
        let deltaX = Double(tileX) + 0.5 - centerX
        let deltaY = Double(tileY) + 0.5 - centerY
        let distance = (deltaX * deltaX + deltaY * deltaY).squareRoot()

        // Outside the silhouette → water.
        let shoreline = islandRadius + shorelineWobble(tileX: tileX, tileY: tileY)
        if distance > shoreline { return .water }
        // Inside silhouette, but in the beach ring → beach.
        if distance > shoreline - beachWidth { return .beach }
        // Near the core → mountain (with a wobble so the core isn't a clean circle).
        if distance < mountainRadius + coreWobble(tileX: tileX, tileY: tileY) { return .mountain }
        // Forest patches scattered across the interior.
        if isForestPatch(tileX: tileX, tileY: tileY) { return .forest }
        return .grass
    }

    /// Periodic-but-irregular shoreline shape. Same input → same output.
    private static func shorelineWobble(tileX: Int, tileY: Int) -> Double {
        let phaseX = Double(tileX) * 0.18
        let phaseY = Double(tileY) * 0.21
        return 3.0 * sin(phaseX) + 2.5 * cos(phaseY)
    }

    /// Inner-mountain wobble, smaller amplitude than the shoreline.
    private static func coreWobble(tileX: Int, tileY: Int) -> Double {
        let phaseX = Double(tileX) * 0.35
        let phaseY = Double(tileY) * 0.27
        return 2.0 * sin(phaseX + phaseY)
    }

    /// Returns true for tiles that should be forest. The pattern is two
    /// overlapping waves — periodic but not gridded.
    private static func isForestPatch(tileX: Int, tileY: Int) -> Bool {
        let phaseA = Double(tileX) * 0.42 + Double(tileY) * 0.31
        let phaseB = Double(tileX) * 0.19 - Double(tileY) * 0.47
        let value = sin(phaseA) + 0.7 * cos(phaseB)
        return value > 0.5
    }
}
