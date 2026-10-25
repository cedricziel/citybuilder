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

    /// An icon button's glyph at the body size of the default text setting,
    /// fixed, so the circle behind it does not grow with Dynamic Type.
    func hudIconFont() -> some View {
        font(.system(size: 17)).imageScale(.large)
    }

    /// One line whose words never break: it shrinks to `minimumScale`, then truncates.
    func hudOneLine(minimumScale: CGFloat = 0.7) -> some View {
        lineLimit(1).minimumScaleFactor(minimumScale)
    }
}
