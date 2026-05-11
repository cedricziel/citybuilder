import CityCore
import CoreGraphics
import Foundation

/// Frame interpolation between two consecutive simulation snapshots.
/// Simulation ticks at 10 Hz; display refreshes at 60-120 Hz. Visual
/// positions for moving entities (carriers in M4+) are produced by linear
/// interpolation of their per-snapshot positions.
///
/// Per spec rendering-2_5d "Frame interpolation between ticks".
public enum FrameInterpolation {
    /// Linear interpolation of one scalar between `a` and `b` at alpha
    /// `progress` ∈ [0, 1]. Progress is clamped so callers can pass raw
    /// fractional through-tick values without bounds checking.
    public static func lerp(_ valueA: Double, _ valueB: Double, at progress: Double) -> Double {
        let clamped = min(max(progress, 0), 1)
        return valueA + (valueB - valueA) * clamped
    }

    /// Linear interpolation of a tile-space position, returned as fractional
    /// tile coordinates. The renderer projects the result to screen-space
    /// via IsoMath.screenPoint(forTileFractionalX:fractionalY:).
    public static func interpolatedTilePosition(
        from previous: (col: Double, row: Double),
        to current: (col: Double, row: Double),
        at progress: Double
    ) -> (col: Double, row: Double) {
        (
            col: lerp(previous.col, current.col, at: progress),
            row: lerp(previous.row, current.row, at: progress)
        )
    }

    /// Progress through a tick given the wall-clock time since the last
    /// tick boundary. Clamps to [0, 1]; 1 means "tick complete, ready for
    /// next snapshot".
    public static func tickProgress(
        wallClockSinceLastTick: TimeInterval,
        tickDurationSeconds: TimeInterval = 0.1
    ) -> Double {
        guard tickDurationSeconds > 0 else { return 1 }
        return min(max(wallClockSinceLastTick / tickDurationSeconds, 0), 1)
    }
}
