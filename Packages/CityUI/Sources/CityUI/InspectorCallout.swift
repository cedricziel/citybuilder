import CityCore
import CoreGraphics
import Foundation

/// Places the inspector callout next to the selected building. Spec:
/// `platform-shells` / Inspector callout.
public enum InspectorCalloutLayout {
    public static let width: CGFloat = 220
    public static let margin: CGFloat = 8
    /// Gap between the building's center and the callout.
    public static let gap: CGFloat = 48

    /// Top-left corner of a callout of `calloutSize` for a building whose
    /// center is `anchor`, clamped inside `viewSize`.
    public static func origin(anchor: CGPoint, calloutSize: CGSize, viewSize: CGSize, placement: HUDDock) -> CGPoint {
        let raw = switch placement {
        case .leftRail:
            CGPoint(x: anchor.x + gap, y: anchor.y - calloutSize.height / 2)
        case .bottomDock:
            CGPoint(x: anchor.x - calloutSize.width / 2, y: anchor.y + gap)
        }
        return CGPoint(
            x: clamp(raw.x, length: calloutSize.width, in: viewSize.width),
            y: clamp(raw.y, length: calloutSize.height, in: viewSize.height)
        )
    }

    private static func clamp(_ value: CGFloat, length: CGFloat, in extent: CGFloat) -> CGFloat {
        max(margin, min(value, extent - margin - length))
    }
}

/// Spec: `platform-shells` / Inspector callout.
public extension GameSession {
    /// The callout's Demolish: demolishes the selected building and clears
    /// the selection.
    func demolishSelection() {
        guard let tile = selectedTile else { return }
        world.enqueue(.demolish(at: tile))
        selectedTile = nil
    }
}
