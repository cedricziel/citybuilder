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

    /// What a container animates a panel showing `content` on: only whether it shows, so a panel
    /// whose text changes to another's swaps it at once instead of cross-fading the two.
    static func presence(of content: (some Equatable)?) -> Bool {
        content != nil
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

    /// Animates a panel showing `content` in this container as it comes and goes, not when
    /// `content` changes to another: the new text replaces the old.
    func panelAnimation(presenceOf content: (some Equatable)?) -> some View {
        panelAnimation(value: PanelMotion.presence(of: content))
    }

    /// Swaps this panel's content at once when `value` changes, while the containers around it
    /// may still animate where it sits.
    func swapsContentAtOnce(on value: some Equatable) -> some View {
        transaction(value: value) { $0.animation = nil }
    }
}
