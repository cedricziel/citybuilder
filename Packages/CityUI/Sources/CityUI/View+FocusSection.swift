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
}
