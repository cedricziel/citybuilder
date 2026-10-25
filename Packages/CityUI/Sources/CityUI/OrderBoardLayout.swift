import CoreGraphics
import SwiftUI

/// Where the order board sits and how wide it is. Spec: `platform-shells`
/// / Order board layout.
public enum OrderBoardLayout {
    /// Shorter than this, the board is not worth a column.
    public static let minHeight: CGFloat = 160
    /// The tool strip's band above the bottom edge when no minimap shares
    /// that row.
    static let toolStripBand: CGFloat = 64

    public enum Presentation: Equatable, Sendable {
        case column
        case sheet
    }

    public static func width(for idiom: HUDIdiom) -> CGFloat {
        switch idiom {
        case .phone: 300
        case .pad, .mac: 340
        case .tv: 520
        }
    }

    /// A sheet where the column has no room: a phone in portrait or a
    /// window narrower than 600 points with the dock.
    public static func presentation(for layout: HUDLayout) -> Presentation {
        layout.placement == .bottomDock && (layout.isPhone || layout.isCompactWidth) ? .sheet : .column
    }

    /// What the board shows as: the column when its frame fits, else the
    /// sheet, so the chip always opens something.
    public static func presentation(
        in size: CGSize, insets: EdgeInsets, layout: HUDLayout, showsMinimap: Bool, showsFirstSteps: Bool
    ) -> Presentation {
        frame(in: size, insets: insets, layout: layout, showsMinimap: showsMinimap, showsFirstSteps: showsFirstSteps) == nil
            ? .sheet : .column
    }

    /// One replaces the other where the callout, the board and the rail
    /// cannot fit together.
    public static func replacesInspector(layout: HUDLayout) -> Bool {
        layout.isPhone || layout.isCompactWidth || layout.isCompactHeight
    }

    /// The board's frame in full-screen coordinates, or nil when it is a
    /// sheet or there is no room. It uses the callout's free area, so it
    /// clears the top bar, the minimap, the first-steps capsule, the rail
    /// and the dock, and the tool strip's row.
    public static func frame(
        in size: CGSize, insets: EdgeInsets, layout: HUDLayout, showsMinimap: Bool, showsFirstSteps: Bool
    ) -> CGRect? {
        guard presentation(for: layout) == .column else { return nil }
        let free = InspectorCalloutLayout.freeArea(
            size: size, insets: insets, layout: layout.withFirstStepsCollapsed, showsMinimap: showsMinimap,
            showsFirstSteps: showsFirstSteps
        )
        var bottom = free.maxY
        if layout.placement == .leftRail, !showsMinimap {
            bottom = min(bottom, size.height - insets.bottom - layout.margin - toolStripBand)
        }
        let width = width(for: layout.idiom)
        let frame = CGRect(
            x: size.width - insets.trailing - layout.margin - width, y: free.minY, width: width, height: bottom - free.minY
        )
        return frame.height >= minHeight ? frame : nil
    }
}
