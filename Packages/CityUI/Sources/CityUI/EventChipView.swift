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

/// Where the chip fits: under the date, never wider than half a narrow HUD,
/// and only the glyph and the season when the HUD is phone-narrow.
enum EventChipLayout {
    static let height: CGFloat = 26
    /// Below this HUD width the chip drops its words but the season.
    static let fullTextWidth: CGFloat = 340

    static func showsText(hudWidth: CGFloat) -> Bool {
        hudWidth >= fullTextWidth
    }

    static func maxWidth(hudWidth: CGFloat) -> CGFloat {
        hudWidth / 2
    }
}

/// The amber glass chip of the approved canvas (Warning, option B). Tapping
/// it shows the warning again.
struct EventChipView: View {
    let chip: EventChip?
    let hudWidth: CGFloat
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
                    Text(EventChipLayout.showsText(hudWidth: hudWidth) ? chip.text : chip.season.displayName)
                        .font(.caption.weight(.semibold))
                        .hudOneLine()
                }
                .foregroundStyle(amber)
                .padding(.leading, 4)
                .padding(.trailing, 10)
                .frame(height: EventChipLayout.height)
                .frame(maxWidth: EventChipLayout.maxWidth(hudWidth: hudWidth), alignment: .leading)
                .fixedSize(horizontal: true, vertical: false)
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
