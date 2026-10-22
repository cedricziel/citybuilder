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
        if let deficitHint { return deficitHint }
        guard let state = bannerState, world.tickCount < state.hidesAtTick else { return nil }
        return state.banner
    }

    func noteBannerEvents(in events: [WorldEvent]) {
        defer { noteDeficitHint(in: events) }
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

    /// The first `bankruptcyWarning` of the session shows the deficit
    /// hint, after the tick's other banners so it takes their place.
    private func noteDeficitHint(in events: [WorldEvent]) {
        if events.contains(where: { if case .bankruptcyWarning = $0 { true } else { false } }) {
            showDeficitHint()
        }
    }

    /// Shows the deficit hint once per session and holds the simulation.
    func showDeficitHint() {
        guard !hasShownDeficitHint else { return }
        hasShownDeficitHint = true
        let figures = world.playerTaxAndUpkeep
        deficitHint = Self.deficitHint(upkeep: figures.upkeep, tax: figures.tax)
    }

    /// Resume, the pause control or Esc: the simulation runs again.
    public func dismissDeficitHint() {
        deficitHint = nil
    }

    /// Spec: `platform-shells` / Deficit hint.
    private static func deficitHint(upkeep: Int64, tax: Int64) -> SessionBanner {
        SessionBanner(
            title: "In the red: upkeep $\(upkeep) vs tax $\(tax)",
            description: "Sell surplus at the town center's market, demolish idle buildings, or build houses before more huts."
        )
    }

    private func show(_ banner: SessionBanner) {
        bannerState = (banner, world.tickCount + Self.bannerTicks)
    }
}

/// Parchment-coloured card announcing a history event or a new age. With
/// `onResume` it holds the game and offers Resume (`deficit-hint` D1).
struct SessionBannerView: View {
    let banner: SessionBanner?
    var onResume: (() -> Void)?
    @FocusState private var resumeFocused: Bool

    var body: some View {
        if let banner {
            VStack(spacing: 2) {
                Text(banner.title)
                    .font(.headline)
                Text(banner.description)
                    .font(.caption)
                    .multilineTextAlignment(.center)
                if let onResume {
                    Button("Resume", action: onResume)
                        .buttonStyle(.borderedProminent)
                        .tint(Color(red: 0.42, green: 0.29, blue: 0.16))
                        .padding(.top, 4)
                        .focused($resumeFocused)
                        .onAppear { resumeFocused = true }
                }
            }
            .foregroundStyle(Color(red: 0.24, green: 0.16, blue: 0.08))
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Color(red: 0.93, green: 0.86, blue: 0.70), in: RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color(red: 0.42, green: 0.29, blue: 0.16), lineWidth: 2))
            .padding(.horizontal, 24)
            .panelTransition(.slide(.top))
            .accessibilityElement(children: onResume == nil ? .combine : .contain)
        }
    }
}
