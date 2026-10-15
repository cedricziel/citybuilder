import SwiftUI

/// How HUD panels enter and leave. Spec: `platform-shells` / HUD panels
/// animate in and out.
enum PanelMotion {
    enum Style: Equatable {
        case slide(Edge)
        /// Rise `riseOffset` points into place, for panels that float over
        /// the map rather than sit on an edge.
        case rise
        case fade
    }

    static let riseOffset: CGFloat = 12

    /// Reduce Motion turns every style into a fade.
    static func style(_ style: Style, reduceMotion: Bool) -> Style {
        reduceMotion ? .fade : style
    }

    /// The build drawer slides out of the rail's side.
    static func drawerStyle(for dock: HUDDock) -> Style {
        .slide(dock == .leftRail ? .leading : .bottom)
    }

    static func duration(reduceMotion: Bool) -> Double {
        reduceMotion ? 0.15 : 0.3
    }

    static func animation(reduceMotion: Bool) -> Animation {
        reduceMotion
            ? .easeInOut(duration: duration(reduceMotion: true))
            : .spring(duration: duration(reduceMotion: false), bounce: 0.15)
    }

    static func transition(_ style: Style) -> AnyTransition {
        switch style {
        case let .slide(edge): .move(edge: edge).combined(with: .opacity)
        case .rise: .offset(y: riseOffset).combined(with: .opacity)
        case .fade: .opacity
        }
    }
}

private struct PanelTransitionModifier: ViewModifier {
    let style: PanelMotion.Style
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content.transition(PanelMotion.transition(PanelMotion.style(style, reduceMotion: reduceMotion)))
    }
}

private struct PanelAnimationModifier<Value: Equatable>: ViewModifier {
    let value: Value
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content.animation(PanelMotion.animation(reduceMotion: reduceMotion), value: value)
    }
}

extension View {
    /// The transition of a panel that comes and goes; pair it with
    /// `panelAnimation(value:)` on a container that stays.
    func panelTransition(_ style: PanelMotion.Style) -> some View {
        modifier(PanelTransitionModifier(style: style))
    }

    /// Animates panels in this container when `value`, and only it, changes.
    func panelAnimation(value: some Equatable) -> some View {
        modifier(PanelAnimationModifier(value: value))
    }
}
