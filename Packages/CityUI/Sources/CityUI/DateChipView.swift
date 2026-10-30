import CityCore
import SwiftUI

/// Where the phone HUD shows the date and when it gives way. A phone's
/// status pill has no room for it, so the date sits in a small chip under
/// the pill, level with the first-steps capsule on the other side. Spec:
/// `platform-shells` / Phone date chip.
enum DateChipLayout {
    static let height: CGFloat = 26
    /// What the chip and the first-steps capsule need side by side, plus the gap between them.
    static let width: CGFloat = 112
    static let firstStepsWidth: CGFloat = 214
    static let gap: CGFloat = 8

    /// The chip shows on a phone, and gives way first when the row is tight: large text, or a
    /// screen too narrow for the chip beside the first-steps capsule.
    static func isShown(layout: HUDLayout, hudWidth: CGFloat, showsFirstSteps: Bool, typeSize: DynamicTypeSize) -> Bool {
        guard layout.isPhone, typeSize < .accessibility1 else { return false }
        return !showsFirstSteps || hudWidth >= width + gap + firstStepsWidth
    }
}

/// A season glyph and "Autumn 1203", under the status pill on a phone.
struct DateChipView: View {
    let hud: HUDViewModel
    let layout: HUDLayout
    let hudWidth: CGFloat
    let showsFirstSteps: Bool
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        let isShown = DateChipLayout.isShown(
            layout: layout, hudWidth: hudWidth, showsFirstSteps: showsFirstSteps, typeSize: typeSize
        )
        if isShown, !hud.dateText.isEmpty {
            HStack(spacing: 5) {
                Image(systemName: hud.seasonSymbol)
                    .font(.system(size: 12, weight: .semibold))
                    .accessibilityHidden(true)
                Text(hud.dateText)
                    .font(.caption.weight(.semibold))
                    .hudOneLine()
            }
            .foregroundStyle(.secondary)
            .padding(.horizontal, 10)
            .frame(height: DateChipLayout.height)
            .background(.thinMaterial, in: Capsule())
            .hudChromeTypeSize()
            .allowsHitTesting(false)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(GameText.string("a11y.date", hud.dateText))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 4)
        }
    }
}
