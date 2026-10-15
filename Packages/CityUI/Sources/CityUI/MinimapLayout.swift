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

    static func cardSize(for idiom: HUDIdiom) -> CGSize {
        let map = mapSize(for: idiom)
        return CGSize(width: map.width + padding * 2, height: map.height + padding * 2)
    }

    /// Bottom-right beside the tool strip with the rail; top-right under
    /// the menu buttons with the dock.
    public static func corner(for layout: HUDLayout) -> Corner {
        layout.placement == .leftRail ? .bottomTrailing : .topTrailing
    }

    /// The minimap card in full-screen coordinates, the space the inspector
    /// callout is placed in.
    public static func frame(in size: CGSize, insets: EdgeInsets, layout: HUDLayout) -> CGRect {
        let card = cardSize(for: layout.idiom)
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
/// phone screen. The HUD binds the same key through `@AppStorage`.
/// Spec: `platform-shells` / Minimap toggle. Design D6.
public struct MinimapPreference {
    public static let defaultsKey = "Citybuilder.showsMinimap"
    private let defaults: UserDefaults
    private let idiom: HUDIdiom

    public init(defaults: UserDefaults = .standard, idiom: HUDIdiom) {
        self.defaults = defaults
        self.idiom = idiom
    }

    public static func shownByDefault(on idiom: HUDIdiom) -> Bool {
        idiom != .phone
    }

    public var isShown: Bool {
        get { defaults.object(forKey: Self.defaultsKey) as? Bool ?? Self.shownByDefault(on: idiom) }
        nonmutating set { defaults.set(newValue, forKey: Self.defaultsKey) }
    }
}
