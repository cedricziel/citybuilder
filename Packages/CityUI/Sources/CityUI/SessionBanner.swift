import CityCore
import SwiftUI

/// A short-lived announcement: a history event or a new age.
public struct SessionBanner: Equatable, Sendable {
    public let title: String
    public let description: String
}

extension GameSession {
    static let bannerTicks: UInt64 = 60
    static let gameOverBanner = SessionBanner(
        title: "Bankrupt",
        description: "The treasury stayed in the red too long and the town is lost. "
            + "You can still save from the pause menu, or quit to the title to load a save or start a new game."
    )

    public var isGameOver: Bool {
        world.isBankrupt
    }

    /// The banner showing now, if any. Spec: `platform-shells` / History
    /// events show a banner, Age changes show a banner, Game-over banner
    /// and tools.
    public var banner: SessionBanner? {
        if isGameOver { return Self.gameOverBanner }
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
            case .gameOver:
                clearTool()
                cancelPendingPlacement()
                tileMenuRequest = nil
                routeAuthoring = nil
            case .scenarioWon:
                show(SessionBanner(title: "Scenario complete", description: "Every goal is met."))
                isWinSheetPresented = true
            case let .fuelRanOut(_, kind):
                let fuel = kind.fuel.map(InspectorViewModel.fuelName) ?? "fuel"
                show(SessionBanner(
                    title: "\(Self.sentenceCase(kind)) is out of \(fuel)",
                    description: kind.isCultureSignature
                        ? "Its effect halves until carriers bring more."
                        : "Its effects stop until carriers bring more."
                ))
            case .monumentCompleted:
                show(SessionBanner(title: "The monument is complete", description: "Taxes rise by 10%."))
            case .commissionEnded:
                show(SessionBanner(
                    title: "The gallery's commission has ended",
                    description: "Commission new art to inspire the houses again."
                ))
            case let .rivalAgeAdvanced(id, age):
                guard let name = world.rival(id)?.name else { continue }
                show(SessionBanner(title: "\(name) enters the \(age.displayName)", description: "A rival town grows."))
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
        enqueue(.commission(id))
    }

    /// Set or clear the selected caravanserai's export good. Spec:
    /// `platform-shells` / Culture signature inspector.
    public func pickExport(_ good: Good?) {
        guard let tile = selectedTile, let id = world.occupiedTiles[tile], world.buildings[id]?.kind == .caravanserai
        else { return }
        enqueue(.setExport(id, good))
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
