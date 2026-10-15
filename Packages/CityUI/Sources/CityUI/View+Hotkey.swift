import SwiftUI

/// Apple TV has no `keyboardShortcut`, so these compile to nothing there.
extension View {
    @ViewBuilder
    func hotkey(_ key: KeyEquivalent, modifiers: EventModifiers = []) -> some View {
        #if os(tvOS)
        self
        #else
        keyboardShortcut(key, modifiers: modifiers)
        #endif
    }

    /// Escape and ⌘. both toggle pause. On the Mac, Esc steps back
    /// through `MacMapInputHost` instead.
    @ViewBuilder
    func pauseHotkeys() -> some View {
        #if os(macOS)
        hotkey(".", modifiers: .command)
        #else
        hotkey(.escape).hotkey(".", modifiers: .command)
        #endif
    }

    @ViewBuilder
    func cancelActionHotkey() -> some View {
        #if os(tvOS)
        self
        #else
        keyboardShortcut(.cancelAction)
        #endif
    }

    @ViewBuilder
    func defaultActionHotkey() -> some View {
        #if os(tvOS)
        self
        #else
        keyboardShortcut(.defaultAction)
        #endif
    }
}
