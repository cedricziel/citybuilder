import CoreGraphics
import Foundation
import SwiftUI

/// Where the minimap sits and how big it is. Spec: `platform-shells` /
/// Minimap layout. Design D5.
public enum MinimapLayout {
    /// The Mac key that shows and hides the minimap.
    public static let hotkey: Character = "m"
    /// Inset of the map image inside its card.
    static let padding: CGFloat = 4
    /// Gap between the minimap and the inspector callout's free area.
    static let gap: CGFloat = 8

    public enum Corner: Equatable, Sendable {
        case topTrailing, bottomTrailing
    }

    /// The map image's size; always 2:1, like the map's iso bounding box.
    public static func mapSize(for idiom: HUDIdiom) -> CGSize {
        switch idiom {
        case .phone: CGSize(width: 144, height: 72)
        case .pad: CGSize(width: 224, height: 112)
        case .mac, .tv: CGSize(width: 240, height: 120)
        }
    }

    /// The map image's size for `layout`: the phone's in a compact width.
    public static func mapSize(for layout: HUDLayout) -> CGSize {
        mapSize(for: layout.isCompactWidth ? .phone : layout.idiom)
    }

    static func cardSize(for layout: HUDLayout) -> CGSize {
        let map = mapSize(for: layout)
        return CGSize(width: map.width + padding * 2, height: map.height + padding * 2)
    }

    /// Bottom-right beside the tool strip with the rail; top-right under
    /// the menu buttons with the dock.
    public static func corner(for layout: HUDLayout) -> Corner {
        layout.placement == .leftRail ? .bottomTrailing : .topTrailing
    }

    /// The width the stocks tray and the session banner may take beside the
    /// minimap in the dock layout, for a HUD `hudWidth` points wide inside
    /// its margins.
    public static func trayColumnWidth(hudWidth: CGFloat, layout: HUDLayout, showsMinimap: Bool) -> CGFloat {
        let card = showsMinimap && corner(for: layout) == .topTrailing ? cardSize(for: layout).width + 8 : 0
        return max(0, hudWidth - layout.railInset - card)
    }

    /// The minimap card in full-screen coordinates, the space the inspector
    /// callout is placed in.
    public static func frame(in size: CGSize, insets: EdgeInsets, layout: HUDLayout) -> CGRect {
        let card = cardSize(for: layout)
        let originX = size.width - insets.trailing - layout.margin - card.width
        let originY = switch corner(for: layout) {
        case .bottomTrailing: size.height - insets.bottom - layout.margin - card.height
        case .topTrailing: InspectorCalloutLayout.topBarBottom(topInset: insets.top, layout: layout)
        }
        return CGRect(origin: CGPoint(x: originX, y: originY), size: card)
    }
}

/// Whether the player shows the minimap, kept in user defaults. With
/// nothing stored it shows on iPad and Mac and stays hidden on the tight
/// phone screen. Spec: `platform-shells` / Minimap toggle. Design D6.
public enum MinimapPreference {
    public static let defaultsKey = "Citybuilder.showsMinimap"

    public static func shownByDefault(on idiom: HUDIdiom) -> Bool {
        idiom != .phone
    }

    /// The HUD's binding to the stored choice.
    public static func storage(idiom: HUDIdiom, store: UserDefaults? = nil) -> AppStorage<Bool> {
        AppStorage(wrappedValue: shownByDefault(on: idiom), defaultsKey, store: store)
    }
}
