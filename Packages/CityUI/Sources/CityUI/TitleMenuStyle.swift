import SwiftUI

/// Staggered fade-and-rise of the title and its menu buttons. Spec:
/// `platform-shells` / Title menu entrance.
enum MenuEntrance {
    static let stagger = 0.08
    static let rise: CGFloat = 16

    static func delay(index: Int) -> Double {
        Double(index) * stagger
    }

    static func offset(entered: Bool, reduceMotion: Bool) -> CGFloat {
        entered || reduceMotion ? 0 : rise
    }

    static func animation(index: Int, reduceMotion: Bool) -> Animation? {
        reduceMotion ? nil : .easeOut(duration: 0.45).delay(delay(index: index))
    }
}

private struct MenuEntranceModifier: ViewModifier {
    let index: Int
    let entered: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        let visible = entered || reduceMotion
        content
            .opacity(visible ? 1 : 0)
            .offset(y: MenuEntrance.offset(entered: entered, reduceMotion: reduceMotion))
            .animation(MenuEntrance.animation(index: index, reduceMotion: reduceMotion), value: entered)
    }
}

#if !os(tvOS)
/// Title menu button look on iPhone, iPad and Mac: a capsule that shrinks
/// when pressed and lifts under the pointer. Spec: `platform-shells` /
/// Title menu buttons respond to touch and pointer.
struct TitleMenuButtonStyle: ButtonStyle {
    var prominent = false

    static func scale(pressed: Bool, hovered: Bool, reduceMotion: Bool) -> CGFloat {
        guard !reduceMotion else { return 1 }
        if pressed { return 0.96 }
        return hovered ? 1.03 : 1
    }

    static func brightness(pressed: Bool, hovered: Bool) -> Double {
        if pressed { return -0.12 }
        return hovered ? 0.06 : 0
    }

    func makeBody(configuration: Configuration) -> some View {
        TitleMenuButtonBody(configuration: configuration, prominent: prominent)
    }
}

private struct TitleMenuButtonBody: View {
    let configuration: ButtonStyleConfiguration
    let prominent: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.isEnabled) private var isEnabled
    @State private var hovered = false

    var body: some View {
        let pressed = configuration.isPressed
        configuration.label
            .frame(maxWidth: 280)
            .padding(.vertical, 10)
            .foregroundStyle(prominent ? Color.white : Color.primary)
            .background {
                if prominent {
                    Capsule().fill(Color(red: 0.62, green: 0.36, blue: 0.16).gradient)
                } else {
                    Capsule().fill(.regularMaterial)
                }
            }
            .overlay(Capsule().strokeBorder(.white.opacity(0.25), lineWidth: 1))
            .contentShape(Capsule())
            .shadow(color: .black.opacity(hovered ? 0.35 : 0.2), radius: hovered ? 10 : 4, y: hovered ? 4 : 2)
            .brightness(TitleMenuButtonStyle.brightness(pressed: pressed, hovered: hovered))
            .scaleEffect(TitleMenuButtonStyle.scale(pressed: pressed, hovered: hovered, reduceMotion: reduceMotion))
            .opacity(isEnabled ? 1 : 0.5)
            .animation(reduceMotion ? nil : .spring(response: 0.25, dampingFraction: 0.7), value: pressed)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.15), value: hovered)
            .onHover { hovered = isEnabled && $0 }
    }
}
#endif

extension View {
    func menuEntrance(_ index: Int, entered: Bool) -> some View {
        modifier(MenuEntranceModifier(index: index, entered: entered))
    }

    /// The title menu's button style. Apple TV keeps the system bordered
    /// styles, whose focus lift and tilt are the native ones.
    @ViewBuilder
    func titleMenuButtonStyle(prominent: Bool = false) -> some View {
        #if os(tvOS)
        if prominent {
            frame(maxWidth: 280).buttonStyle(.borderedProminent)
        } else {
            frame(maxWidth: 280).buttonStyle(.bordered)
        }
        #else
        buttonStyle(TitleMenuButtonStyle(prominent: prominent))
        #endif
    }
}
