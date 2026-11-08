import SwiftUI

/// The paper the panels that describe the town are drawn on: the inspector
/// callout, the build drawer, the Statistics sheet and the banners. Spec:
/// `platform-shells` / Parchment panels.
enum Parchment {
    static let paperHex: UInt32 = 0xEDDDB3
    static let edgeHex: UInt32 = 0x6B4A29
    static let inkHex: UInt32 = 0x3D2914

    static let paper = Color(rgb: paperHex)
    static let edge = Color(rgb: edgeHex)
    static let ink = Color(rgb: inkHex)
    /// A tile, chip or button raised from the page.
    static let raised = Color(rgb: 0xF7ECD0)
    /// A tile or chip sunk into the page.
    static let sunk = edge.opacity(0.12)
    static let alert = Color(rgb: 0x8A2A1A)
    static let onAlert = Color(rgb: 0xFBEEDD)
    static let short = Color(rgb: 0xE9B67A)
    static let onShort = Color(rgb: 0x5C2A00)
    static let meter = Color(rgb: 0x5C7A2E)
    static let edgeWidth: CGFloat = 2

    static func title(_ style: Font.TextStyle = .headline) -> Font {
        .system(style, design: .serif).weight(.bold)
    }
}

extension Color {
    /// A colour from 0xRRGGBB.
    init(rgb: UInt32) {
        self.init(
            red: Double((rgb >> 16) & 0xFF) / 255,
            green: Double((rgb >> 8) & 0xFF) / 255,
            blue: Double(rgb & 0xFF) / 255
        )
    }
}

extension View {
    /// Paper, edge and ink, in the light appearance whatever the system's,
    /// so `.secondary` text stays a lighter ink on the paper.
    func parchmentPanel(cornerRadius: CGFloat = 10) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        return foregroundStyle(Parchment.ink)
            .tint(Parchment.edge)
            .environment(\.colorScheme, .light)
            .background(Parchment.paper, in: shape)
            .overlay(shape.strokeBorder(Parchment.edge, lineWidth: Parchment.edgeWidth))
            .shadow(color: .black.opacity(0.3), radius: 9, y: 4)
    }
}
