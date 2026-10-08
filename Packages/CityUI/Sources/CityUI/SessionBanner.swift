import CityCore
import SwiftUI

/// A short-lived announcement: a history event or a new age.
public struct SessionBanner: Equatable, Sendable {
    public let title: String
    public let description: String
}

extension GameSession {
    static let bannerTicks: UInt64 = 60

    /// The banner showing now, if any. Spec: `platform-shells` / History
    /// events show a banner, Age changes show a banner.
    public var banner: SessionBanner? {
        guard let state = bannerState, world.tickCount < state.hidesAtTick else { return nil }
        return state.banner
    }

    func noteBannerEvents(in events: [WorldEvent]) {
        for event in events {
            switch event {
            case let .historyEvent(history):
                show(SessionBanner(title: history.title, description: history.description))
            case let .ageAdvanced(age):
                show(SessionBanner(title: "The \(age.displayName) age begins", description: age.blurb))
            case .scenarioWon:
                show(SessionBanner(title: "Scenario complete", description: "Every goal is met."))
                isWinSheetPresented = true
            case let .fuelRanOut(_, kind):
                let fuel = kind.fuel.map(InspectorViewModel.fuelName) ?? "fuel"
                show(SessionBanner(
                    title: "\(Self.sentenceCase(kind)) is out of \(fuel)",
                    description: "Its effects stop until carriers bring more."
                ))
            case .monumentCompleted:
                show(SessionBanner(title: "The monument is complete", description: "Taxes rise by 10%."))
            case .commissionEnded:
                show(SessionBanner(
                    title: "The gallery's commission has ended",
                    description: "Commission new art to inspire the houses again."
                ))
            default:
                continue
            }
        }
    }

    /// "Steam engine" from the palette's "Steam Engine".
    static func sentenceCase(_ kind: BuildingKind) -> String {
        let name = BuildTool.place(kind).displayName.lowercased()
        return name.prefix(1).uppercased() + name.dropFirst()
    }

    /// Pay for a commission at the selected gallery. Spec: `platform-shells`
    /// / Signature inspector.
    public func commissionArt() {
        guard let tile = selectedTile, let id = world.occupiedTiles[tile], world.buildings[id]?.kind == .gallery else { return }
        world.enqueue(.commission(id))
    }

    private func show(_ banner: SessionBanner) {
        bannerState = (banner, world.tickCount + Self.bannerTicks)
    }
}

/// Parchment-coloured card announcing a history event or a new age.
struct SessionBannerView: View {
    let banner: SessionBanner?

    var body: some View {
        if let banner {
            VStack(spacing: 2) {
                Text(banner.title)
                    .font(.headline)
                Text(banner.description)
                    .font(.caption)
                    .multilineTextAlignment(.center)
            }
            .foregroundStyle(Color(red: 0.24, green: 0.16, blue: 0.08))
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Color(red: 0.93, green: 0.86, blue: 0.70), in: RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color(red: 0.42, green: 0.29, blue: 0.16), lineWidth: 2))
            .padding(.horizontal, 24)
            .transition(.move(edge: .top).combined(with: .opacity))
            .accessibilityElement(children: .combine)
        }
    }
}
