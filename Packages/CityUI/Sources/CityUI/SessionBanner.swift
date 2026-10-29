import CityCore
import SwiftUI

/// A short-lived announcement: a history event or a new age.
public struct SessionBanner: Equatable, Sendable {
    public let title: String
    public let description: String
}

extension GameSession {
    static let bannerTicks: UInt64 = 60
    /// Ticks between one banner hiding and the next showing, so the two
    /// never draw at once while one slides out and the other in.
    static let bannerGapTicks: UInt64 = 5
    /// Banners waiting at most; past it the oldest that isn't urgent goes.
    static let bannerQueueLimit = 8
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
        showNextBanner()
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
                if let seasonal = seasonalEventBanner(for: event) {
                    show(seasonal, isUrgent: event.isIgnition)
                } else {
                    noteOrderEvent(event)
                }
            }
        }
    }

    /// Order offers, fills, misses and lapses. Spec: `platform-shells` /
    /// Order notifications. Orders that are gone show nothing.
    private func noteOrderEvent(_ event: WorldEvent) {
        switch event {
        case let .orderOffered(id, _):
            guard let order = world.order(id) else { return }
            let name = OrdersBoardModel.name(of: order.issuer, in: world)
            let verb = order.issuer == .crown ? "orders" : "wants"
            show(expiringAt: order.offerEndsTick, SessionBanner(
                title: "\(name) \(verb) \(order.quantity) \(InspectorViewModel.goodName(order.good))",
                description: "\(order.template.title), \(OrdersBoardModel.deadlineText(order, in: world)). "
                    + "Pays \(HUDViewModel.formatMoney(order.reward, locale: .current)) and \(order.favourGain) favour. "
                    + "Open the board to accept."
            ))
        case let .orderFulfilled(id, reward):
            guard let order = world.order(id) else { return }
            let name = OrdersBoardModel.name(of: order.issuer, in: world)
            show(SessionBanner(
                title: "Order filled: \(order.quantity) \(InspectorViewModel.goodName(order.good))",
                description: "\(name) pays \(HUDViewModel.formatMoney(reward, locale: .current)), "
                    + "and its favour rises to \(world.orders.favour.value(for: order.issuer))."
            ))
        case let .orderFailed(id):
            guard let order = world.order(id) else { return }
            let name = OrdersBoardModel.name(of: order.issuer, in: world)
            let target = order.issuer == .crown ? "the crown" : name
            show(SessionBanner(
                title: "Order missed: \(InspectorViewModel.goodName(order.good)) for \(target)",
                description: "The deadline passed with \(order.delivered) of \(order.quantity) delivered. "
                    + "\(name)'s favour falls by \(order.favourLoss)."
            ))
        case let .orderExpired(id):
            guard let order = world.order(id) else { return }
            show(SessionBanner(
                title: "An offer from \(OrdersBoardModel.name(of: order.issuer, in: world)) lapsed",
                description: "Ignoring an offer costs nothing."
            ))
        default:
            return
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

    /// The one-time hint that pinch zooms, for a new game's first screen on a touch device. A loaded
    /// save's player knows the gesture, and the store only learns of the hint once it has shown.
    /// Spec: `platform-shells` / Pinch-to-zoom hint.
    public func showPinchZoomHintIfNew(using store: CoachmarkStore) {
        guard offersPinchHint else { return }
        offersPinchHint = false
        guard store.shouldShowPinchZoomHint else { return }
        showPinchZoomHint()
        store.markPinchZoomHintShown()
    }

    func showPinchZoomHint() {
        show(SessionBanner(
            title: "Pinch to zoom",
            description: "Pinch to see more of the island, or to look closer."
        ))
    }

    /// The event chip's tap: the warning of the event warned or under way
    /// again, or that a fire burns. Spec: `platform-shells` / Seasonal events
    /// show banners and a chip.
    public func replaySeasonalWarning() {
        guard let banner = seasonalChipBanner() else { return }
        // The player asked: it takes the slot at once, paused or not.
        bannerQueue.removeAll { $0.banner == banner }
        bannerState = (banner, world.tickCount + Self.bannerTicks)
    }

    /// Resume, the pause control or Esc: the simulation runs again.
    public func dismissDeficitHint() {
        deficitHint = nil
    }

    /// Spec: `platform-shells` / Deficit hint.
    private static func deficitHint(upkeep: Int64, tax: Int64) -> SessionBanner {
        SessionBanner(
            title: "In the red: upkeep $\(upkeep) vs tax $\(tax)",
            description: "Residents pay tax only when fed. Build a farm, fill your houses, and sell surplus at the town center's market."
        )
    }

    /// The first time this session a good piles up that nothing in town
    /// uses, a banner names it and what would, once no other banner
    /// shows. A good whose user an open first step already asks for
    /// waits until that step is met or the card is hidden. Spec:
    /// `platform-shells` / Idle-good hint.
    func noteIdleGoods() {
        guard !isBannerBusy, deficitHint == nil, !isGameOver else { return }
        let asked = firstStepsGuide?.openStepKinds ?? []
        guard let idle = world.idleGoods(of: .player).first(where: {
            !hintedIdleGoods.contains($0.good) && asked.isDisjoint(with: $0.users)
        })
        else { return }
        hintedIdleGoods.insert(idle.good)
        show(Self.idleGoodHint(idle))
    }

    /// Ticks a problem has to stand before the hint names it: placing a farm and then its road
    /// clears "no road" before the player could read the banner.
    static let problemHintDelayTicks: UInt64 = 100

    /// The first time a player's building has stood with a given problem for
    /// `problemHintDelayTicks`, a banner names the building and the problem, once no other banner
    /// shows. The status icon over the building has no words; this is where they come from, and
    /// tapping the building shows the same line in its callout. Spec: `platform-shells` /
    /// Building-problem hint.
    func noteBuildingProblems(in snapshot: WorldSnapshot) {
        let problems = playerBuildingProblems(in: snapshot)
        problemsSeen = problemsSeen.filter { problems[$0.key] == $0.value.text }
        for (id, text) in problems where problemsSeen[id] == nil {
            problemsSeen[id] = (text, world.tickCount)
        }
        guard !isBannerBusy, deficitHint == nil, !isGameOver else { return }
        let due = problemsSeen
            .filter { world.tickCount - $0.value.since >= Self.problemHintDelayTicks && !hintedProblems.contains($0.value.text) }
            .min { $0.key.raw < $1.key.raw }
        guard let (id, seen) = due, let building = snapshot.buildings[id] else { return }
        hintedProblems.insert(seen.text)
        show(Self.problemHint(name: BuildTool.place(building.kind).displayName, problem: seen.text))
    }

    /// The problem text of each of the player's buildings that shows a status icon.
    private func playerBuildingProblems(in snapshot: WorldSnapshot) -> [EntityID: String] {
        var problems: [EntityID: String] = [:]
        let isPlayers = { (id: EntityID) in snapshot.buildings[id]?.owner == .player }
        for id in snapshot.roadDisconnectedBuildings where isPlayers(id) {
            problems[id] = InspectorViewModel.problemText(.noRoad)
        }
        for (id, issue) in snapshot.buildingIssues where isPlayers(id) {
            problems[id] = InspectorViewModel.problemText(issue)
        }
        return problems
    }

    static func problemHint(name: String, problem: String) -> SessionBanner {
        SessionBanner(title: "\(name) has a problem", description: "\(problem). Tap it for details.")
    }

    static func idleGoodHint(_ idle: IdleGood) -> SessionBanner {
        let good = GoodsCatalog.spec(for: idle.good).displayName.lowercased()
        // The raw value names the building ("charcoal-burner"); the
        // palette's short label names its good ("Charcoal").
        let builds = idle.users.map { "a " + $0.rawValue.replacingOccurrences(of: "-", with: " ") }
        let named = builds.count < 2 ? builds.joined() : builds.dropLast().joined(separator: ", ") + " or " + builds[builds.count - 1]
        return SessionBanner(
            title: "Nothing uses your \(good)",
            description: "Build \(named) for it, or sell \(good) at the town center's market."
        )
    }

    /// A banner shows, or waits while one shows: one at a time, each once.
    /// An urgent one ("Fire!") goes ahead of the others, and a newer urgent
    /// one with the same title takes the place of the one waiting.
    /// A banner that goes stale at `expiringAt` (an order offer that lapses)
    /// is dropped if it is still waiting then.
    private func show(expiringAt expiry: UInt64? = nil, _ banner: SessionBanner, isUrgent: Bool = false) {
        guard bannerState?.banner != banner || !isBannerShowing, !bannerQueue.contains(where: { $0.banner == banner }) else { return }
        if isUrgent {
            bannerQueue.removeAll { $0.isUrgent && $0.banner.title == banner.title }
        }
        let place = isUrgent ? bannerQueue.firstIndex { !$0.isUrgent } ?? bannerQueue.endIndex : bannerQueue.endIndex
        bannerQueue.insert(QueuedBanner(banner: banner, isUrgent: isUrgent, expiresAtTick: expiry), at: place)
        if bannerQueue.count > Self.bannerQueueLimit, let oldest = bannerQueue.firstIndex(where: { !$0.isUrgent }) {
            bannerQueue.remove(at: oldest)
        }
        showNextBanner()
    }

    /// The next waiting banner, once the one before has hidden and the gap passed.
    private func showNextBanner() {
        let free = bannerState.map { world.tickCount >= $0.hidesAtTick + Self.bannerGapTicks } ?? true
        bannerQueue.removeAll { $0.expiresAtTick.map { world.tickCount >= $0 } ?? false }
        guard free, !bannerQueue.isEmpty else { return }
        bannerState = (bannerQueue.removeFirst().banner, world.tickCount + Self.bannerTicks)
    }

    private var isBannerShowing: Bool {
        bannerState.map { world.tickCount < $0.hidesAtTick } ?? false
    }

    /// A banner shows or waits, so a hint should hold back.
    private var isBannerBusy: Bool {
        isBannerShowing || !bannerQueue.isEmpty
    }
}

private extension WorldEvent {
    var isIgnition: Bool {
        if case .buildingCaughtFire = self { true } else { false }
    }
}

/// A banner waiting for the slot.
struct QueuedBanner {
    let banner: SessionBanner
    /// "Fire!" goes ahead of the others.
    let isUrgent: Bool
    /// The tick it goes stale at, such as an order offer's end; nil for never.
    let expiresAtTick: UInt64?
}

/// Where the session banner goes. Spec: `platform-shells` / Session banners.
enum SessionBannerLayout {
    /// Narrower than this, the banner's text wraps line by line and it
    /// leaves the HUD's left column.
    static let minWidth: CGFloat = 240

    static func fitsColumn(width: CGFloat) -> Bool {
        width >= minWidth
    }

    /// Off the column, the banner sits this far up from the bottom, above
    /// the dock when there is one.
    static func bottomInset(layout: HUDLayout) -> CGFloat {
        layout.placement == .bottomDock ? 90 : 16
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
            .hudChromeTypeSize()
            .padding(.horizontal, 24)
            .panelTransition(.slide(.top))
            .accessibilityElement(children: onResume == nil ? .combine : .contain)
        }
    }
}
