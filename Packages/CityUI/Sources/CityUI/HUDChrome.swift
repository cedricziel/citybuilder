import SwiftUI

/// How the HUD chrome (the buttons, pills, build bar and hints that sit over
/// the map) answers Dynamic Type. A chrome control that grows with the text
/// covers the map and breaks words, so it stops at `accessibility1` and its
/// text shrinks or truncates instead of wrapping. Sheets and panels are not
/// chrome and keep scaling fully.
extension View {
    /// Caps the text size inside HUD chrome.
    func hudChromeTypeSize() -> some View {
        dynamicTypeSize(...DynamicTypeSize.accessibility1)
    }

    /// An icon button's glyph. On iOS it is fixed at the body size of the default text setting, so the
    /// circle behind it does not grow with Dynamic Type, and the Large Content Viewer shows it large
    /// instead. Other platforms keep their own symbol size: the Mac's 13 pt and Apple TV's focus-sized
    /// glyphs are not Dynamic Type's to change.
    @ViewBuilder
    func hudIconFont() -> some View {
        #if os(iOS)
        font(.system(size: 17)).imageScale(.large).accessibilityShowsLargeContentViewer()
        #else
        imageScale(.large)
        #endif
    }

    /// One line whose words never break: it shrinks to `minimumScale`, then truncates.
    func hudOneLine(minimumScale: CGFloat = 0.7) -> some View {
        lineLimit(1).minimumScaleFactor(minimumScale)
    }
}
