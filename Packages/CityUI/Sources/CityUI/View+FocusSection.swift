import SwiftUI

extension View {
    /// Makes a HUD region one focus section on Apple TV. A swipe toward
    /// the region then lands on its nearest control even when no control
    /// lines up with the focused one, which links the build rail, top
    /// bar, inspector callout and route overlay. Design D7.
    @ViewBuilder
    func tvFocusSection() -> some View {
        #if os(tvOS)
        focusSection()
        #else
        self
        #endif
    }

    /// Gives `value` the initial focus on Apple TV. A disabled control
    /// cannot take focus, so when `enabled` turns true later the focus
    /// moves to `value` then.
    @ViewBuilder
    func tvDefaultFocus<Value: Hashable>(
        _ binding: FocusState<Value>.Binding,
        _ value: Value,
        enabled: Bool = true
    ) -> some View {
        #if os(tvOS)
        defaultFocus(binding, value, priority: .userInitiated)
            .onChange(of: enabled) { _, isEnabled in
                if isEnabled {
                    binding.wrappedValue = value
                }
            }
        #else
        self
        #endif
    }
}
