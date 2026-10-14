import CityCore
import Foundation

/// The tool currently armed for tile interactions. Cycles via taps on
/// the palette buttons (tap once to arm, tap the same button to disarm
/// back to .inspect).
public enum BuildTool: Hashable, Sendable {
    case inspect
    case place(BuildingKind)
    case demolish

    public var displayName: String {
        switch self {
        case .inspect: return "Inspect"
        case .demolish: return "Demolish"
        case let .place(kind): return kind.displayName
        }
    }
}
