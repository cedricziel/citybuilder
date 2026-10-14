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

    /// Escape and ⌘. both toggle pause.
    func pauseHotkeys() -> some View {
        hotkey(.escape).hotkey(".", modifiers: .command)
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
