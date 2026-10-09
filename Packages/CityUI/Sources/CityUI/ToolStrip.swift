import CityCore
import Foundation

/// Text on the tool strip. Spec: `platform-shells` / Tool strip.
public enum ToolStripText {
    public static func hint(for tool: BuildTool, touch: Bool) -> String {
        switch tool {
        case .inspect: ""
        case .demolish: touch ? "Tap a building to demolish" : "Click a building to demolish"
        case .place: touch ? "Tap or drag to place" : "Click or drag to place"
        }
    }

    public static var isTouch: Bool {
        #if os(iOS)
        true
        #else
        false
        #endif
    }
}

/// Spec: `platform-shells` / Tool strip.
public extension GameSession {
    /// The tool strip's material chips: the hovered tile's when there is
    /// one, otherwise the camera-center tile's, so touch players see them
    /// before the first tap. Nil when the armed tool needs no materials.
    var armedCostBreakdown: [Good: GhostCost]? {
        if let ghost = ghostState() { return ghost.costBreakdown }
        guard case let .place(kind) = selectedTool else { return nil }
        return costBreakdown(for: kind, anchor: world.camera.centerTile())
    }
}
