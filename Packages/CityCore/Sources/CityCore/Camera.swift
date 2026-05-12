import Foundation

/// Camera state in tile-space — independent of any renderer. The 2.5D iso
/// projection lives in CityRender2D; CityCore only carries the logical
/// `(x, y, zoom)` so saves can restore the view per spec rendering-2_5d
/// "Camera persists across save/load".
public struct Camera: Hashable, Codable, Sendable {
    /// Center of the view in tile-space (fractional tile coordinates).
    public var centerX: Double
    public var centerY: Double
    /// Scale factor. 1.0 = 1 tile-screen-unit. Larger = zoomed in.
    public var zoom: Double

    public static let minZoom: Double = 0.25
    public static let maxZoom: Double = 4.0

    public init(centerX: Double = 0, centerY: Double = 0, zoom: Double = 1.0) {
        self.centerX = centerX
        self.centerY = centerY
        self.zoom = Self.clampZoom(zoom)
    }

    public mutating func pan(deltaX: Double, deltaY: Double) {
        centerX += deltaX
        centerY += deltaY
    }

    public mutating func setZoom(_ newZoom: Double) {
        zoom = Self.clampZoom(newZoom)
    }

    public mutating func multiplyZoom(by factor: Double) {
        setZoom(zoom * factor)
    }

    public static func clampZoom(_ value: Double) -> Double {
        min(max(value, minZoom), maxZoom)
    }

    /// Returns the integer tile the camera's center is currently over.
    /// Uses floor semantics — tile (x, y) covers the half-open square
    /// `[x, x+1) × [y, y+1)` in tile-space.
    public func centerTile() -> TileCoordinate {
        TileCoordinate(
            x: Int(centerX.rounded(.down)),
            y: Int(centerY.rounded(.down))
        )
    }
}
