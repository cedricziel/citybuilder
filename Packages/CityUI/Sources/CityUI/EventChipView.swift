import CityCore
import SwiftUI

/// The seasonal event warned or under way, as the HUD names it. Spec:
/// `platform-shells` / Seasonal events show banners and a chip.
public struct EventChip: Equatable, Sendable {
    public let event: SeasonalEvent
    public let season: Season

    public init(_ onset: SeasonalEventOnset) {
        event = onset.event
        season = onset.season
    }

    /// "Fire risk · Summer", "Blight · Summer", "Festival · by Autumn".
    public var text: String {
        let season = season.displayName
        return switch event.effect {
        case .fire: "Fire risk · \(season)"
        case .blight: "Blight · \(season)"
        case .fever: "Fever · \(season)"
        case .festival: "Festival · by \(season)"
        }
    }

    var symbol: String {
        switch event.effect {
        case .fire: "flame.fill"
        case .blight: "leaf.fill"
        case .fever: "thermometer.medium"
        case .festival: "party.popper.fill"
        }
    }
}

/// Where the chip fits: in the HUD's left column, beside the first-steps
/// card when it shows. Where the column is too narrow for the words, only
/// the glyph shows, so the text never truncates.
enum EventChipLayout {
    /// The chip's widest text, "Fire risk · Summer", with its glyph.
    static let fullTextWidth: CGFloat = 160

    /// The width the chip has: the HUD less the first-steps card and its gap.
    static func room(hudWidth: CGFloat, showsFirstSteps: Bool) -> CGFloat {
        showsFirstSteps ? hudWidth - DateChipLayout.firstStepsWidth - DateChipLayout.gap : hudWidth
    }

    static func showsText(layout: HUDLayout, hudWidth: CGFloat, showsFirstSteps: Bool) -> Bool {
        !layout.isPhone || room(hudWidth: hudWidth, showsFirstSteps: showsFirstSteps) >= fullTextWidth
    }

    /// As tall as the date chip, and on Apple TV tall enough for its focus highlight.
    static func height(layout: HUDLayout) -> CGFloat {
        layout.focusableHeight(DateChipLayout.height)
    }
}

/// The amber glass chip of the approved canvas (Warning, option B). Tapping
/// it shows the warning again; on Apple TV it is a focusable plain button,
/// which lifts when focused like the other HUD buttons.
struct EventChipView: View {
    let chip: EventChip?
    let layout: HUDLayout
    let hudWidth: CGFloat
    let showsFirstSteps: Bool
    let onTap: () -> Void
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        if let chip {
            Button(action: onTap) {
                HStack(spacing: 6) {
                    Image(systemName: chip.symbol)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 18, height: 18)
                        .background(Color(red: 0.91, green: 0.51, blue: 0.05), in: Circle())
                        .accessibilityHidden(true)
                    if EventChipLayout.showsText(layout: layout, hudWidth: hudWidth, showsFirstSteps: showsFirstSteps) {
                        Text(chip.text)
                            .font(.caption.weight(.semibold))
                            .lineLimit(1)
                            .fixedSize()
                    }
                }
                .foregroundStyle(amber)
                .padding(.leading, 4)
                .padding(.trailing, 10)
                .frame(height: EventChipLayout.height(layout: layout))
                .background(.thinMaterial, in: Capsule())
                .overlay(Capsule().stroke(Color.black.opacity(0.08), lineWidth: 1))
            }
            .buttonStyle(.plain)
            .hudChromeTypeSize()
            .accessibilityLabel("\(chip.text): show the warning again")
            .frame(maxWidth: .infinity, alignment: .leading)
            .transition(.opacity)
        }
    }

    /// The canvas's #8a4b00, lifted for a dark material.
    private var amber: Color {
        colorScheme == .dark ? Color(red: 0.96, green: 0.65, blue: 0.29) : Color(red: 0.54, green: 0.29, blue: 0)
    }
}
