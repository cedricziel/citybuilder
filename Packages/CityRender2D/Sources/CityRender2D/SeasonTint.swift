import CityCore
import SpriteKit

/// Colour wash laid over vegetation per season (design D7): warm in
/// autumn, frosty in winter, none in spring and summer.
enum SeasonTint {
    static let tintedTerrain: Set<TerrainType> = [.grass, .forest]

    static func tint(for season: Season) -> (color: SKColor, blendFactor: CGFloat) {
        switch season {
        case .spring, .summer:
            (.white, 0)
        case .autumn:
            (SKColor(red: 0.85, green: 0.50, blue: 0.18, alpha: 1), 0.25)
        case .winter:
            (SKColor(red: 0.88, green: 0.93, blue: 1.0, alpha: 1), 0.45)
        }
    }
}
