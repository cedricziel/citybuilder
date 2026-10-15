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

    /// Apple TV sheets size to their content, which leaves a narrow
    /// column on a 1920-point screen and truncates the title. A floor
    /// makes room for it.
    @ViewBuilder
    func tvSheetWidth() -> some View {
        #if os(tvOS)
        frame(minWidth: 1000, idealWidth: 1100, minHeight: 600, idealHeight: 800)
            .presentationSizing(.fitted)
        #else
        self
        #endif
    }

    /// Gives `value` the initial focus on Apple TV. A disabled control
    /// cannot take focus, so when `enabled` turns true later, or `value`
    /// changes while enabled, the focus moves to `value` then.
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
            .onChange(of: value) { _, newValue in
                if enabled {
                    binding.wrappedValue = newValue
                }
            }
        #else
        self
        #endif
    }
}
