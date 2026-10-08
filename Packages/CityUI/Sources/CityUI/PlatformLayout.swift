import Foundation

/// Compact / regular size class abstraction that doesn't import SwiftUI
/// so the view-model is fully unit-testable.
public enum LayoutSizeClass: String, Sendable, Codable {
    case compact // iPhone portrait
    case regular // iPad, Mac, iPhone landscape on larger devices
    case mac // explicit Mac variant for menu-bar handling
}

/// Layout decisions derived purely from size class. The HUD reads these
/// values to decide between sidebar / sheet / bottom-bar etc.
public struct LayoutDecisions: Equatable, Sendable {
    public let palettePlacement: PalettePlacement
    public let defaultCameraZoom: Double
    public let showsAdvancedControls: Bool
    public let showsMenuBar: Bool
    public var labels: HUDLabelConfig = .singleLine

    public enum PalettePlacement: String, Sendable {
        case sidebar
        case bottomSheet
        case topBar
    }

    public static func decisions(for sizeClass: LayoutSizeClass) -> LayoutDecisions {
        switch sizeClass {
        case .compact:
            return LayoutDecisions(
                palettePlacement: .bottomSheet,
                defaultCameraZoom: 1.5,
                showsAdvancedControls: false,
                showsMenuBar: false
            )
        case .regular:
            return LayoutDecisions(
                palettePlacement: .sidebar,
                defaultCameraZoom: 1.0,
                showsAdvancedControls: true,
                showsMenuBar: false
            )
        case .mac:
            return LayoutDecisions(
                palettePlacement: .topBar,
                defaultCameraZoom: 1.0,
                showsAdvancedControls: true,
                showsMenuBar: true
            )
        }
    }
}

/// Line-wrapping rules for HUD stat and palette labels. Spec:
/// `platform-shells` / Compact HUD labels stay on one line.
public struct HUDLabelConfig: Equatable, Sendable {
    public let statValueLineLimit: Int
    public let statCaptionLineLimit: Int
    public let paletteLabelLineLimit: Int
    /// Smallest scale a label may shrink to before it truncates.
    public let minimumScaleFactor: Double

    public static let singleLine = HUDLabelConfig(
        statValueLineLimit: 1,
        statCaptionLineLimit: 1,
        paletteLabelLineLimit: 1,
        minimumScaleFactor: 0.7
    )
}

/// Hover tooltip controller — pure timing logic. Determines whether a
/// tooltip should be shown for a given hover target after a delay.
public struct HoverTooltipController: Equatable, Sendable {
    public let delaySeconds: TimeInterval
    public private(set) var currentTarget: String?
    public private(set) var hoverStarted: TimeInterval?

    public init(delaySeconds: TimeInterval = 0.5) {
        self.delaySeconds = delaySeconds
    }

    public mutating func hoverChanged(to target: String?, at time: TimeInterval) {
        if target != currentTarget {
            currentTarget = target
            hoverStarted = target == nil ? nil : time
        }
    }

    public func shouldShowTooltip(at time: TimeInterval) -> Bool {
        guard let start = hoverStarted, currentTarget != nil else { return false }
        return (time - start) >= delaySeconds
    }
}

/// Mac hotkey table.
public enum MacHotkey: String, CaseIterable, Sendable {
    case pause
    case save
    case load
    case openBuildMenu
    case roadTool
    case demolishTool
    case cameraCenter
}
