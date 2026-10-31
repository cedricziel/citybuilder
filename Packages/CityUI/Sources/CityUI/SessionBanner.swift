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
    static var gameOverBanner: SessionBanner {
        SessionBanner(title: GameText.string("banner.bankrupt.title"), description: GameText.string("banner.bankrupt.text"))
    }

    public var isGameOver: Bool {
        world.isBankrupt
    }

    /// The banner showing now, if any. Spec: `platform-shells` / History
    /// events show a banner, Age changes show a banner, Game-over banner
    /// and tools.
    public var banner: SessionBanner? {
        // A chapter's lost card says it instead; one card, not two.
        if isGameOver { return chapterCard == nil ? Self.gameOverBanner : nil }
        if let deficitHint { return deficitHint }
        guard let state = bannerState, world.tickCount < state.hidesAtTick else { return nil }
        return state.banner
    }

    func noteBannerEvents(in events: [WorldEvent]) {
        // The tick's banners queue first, so a Fire! among them wins a free slot.
        isQueueingTickBanners = true
        defer {
            isQueueingTickBanners = false
            showNextBanner()
            noteDeficitHint(in: events)
        }
        for event in events {
            switch event {
            case let .historyEvent(history):
                show(SessionBanner(title: GameText.string(history.titleKey), description: GameText.string(history.message)))
            case let .ageAdvanced(age):
                show(SessionBanner(title: GameText.string("banner.ageBegins", age.displayName), description: age.blurb))
            case .gameOver:
                clearTool()
                cancelPendingPlacement()
                tileMenuRequest = nil
                routeAuthoring = nil
            case .scenarioWon, .scenarioLost:
                noteScenarioEnd(event)
            case let .fuelRanOut(_, kind):
                let fuel = kind.fuel.map(InspectorViewModel.fuelName) ?? GameText.string("banner.fuelGeneric")
                show(SessionBanner(
                    title: GameText.string("banner.fuelOut.title", Self.sentenceCase(kind), fuel),
                    description: kind.isCultureSignature
                        ? GameText.string("banner.fuelOut.halves")
                        : GameText.string("banner.fuelOut.stops")
                ))
            case .monumentCompleted:
                show(SessionBanner(title: GameText.string("banner.monument.title"), description: GameText.string("banner.monument.text")))
            case .commissionEnded:
                show(SessionBanner(
                    title: GameText.string("banner.commission.title"),
                    description: GameText.string("banner.commission.text")
                ))
            case let .rivalAgeAdvanced(id, age):
                guard let name = world.rival(id)?.name else { continue }
                show(SessionBanner(
                    title: GameText.string("banner.rivalAge.title", name, age.displayName),
                    description: GameText.string("banner.rivalAge.text")
                ))
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
        let id: OrderID? = switch event {
        case let .orderOffered(id, _), let .orderFulfilled(id, _): id
        case let .orderFailed(id), let .orderExpired(id): id
        default: nil
        }
        // The festival's own banners speak for the town's orders.
        guard let id, let order = world.order(id), order.issuer.isBoardOrder else { return }
        let name = OrdersBoardModel.name(of: order.issuer, in: world)
        // German declines "the crown" but not a town's name, so the crown has its own
        // sentences; they name it as `OrdersBoardModel.name(of: .crown)` does.
        let isCrown = order.issuer == .crown
        let good = InspectorViewModel.goodName(order.good)
        switch event {
        case .orderOffered:
            show(expiringAt: order.offerEndsTick, SessionBanner(
                title: isCrown
                    ? GameText.string("banner.order.offered.crown", order.quantity, good)
                    : GameText.string("banner.order.offered.rival", name, order.quantity, good),
                description: GameText.string(
                    "banner.order.offered.text", order.template.title, OrdersBoardModel.deadlineText(order, in: world),
                    HUDViewModel.formatMoney(order.reward), order.favourGain
                )
            ))
        case let .orderFulfilled(_, reward):
            show(SessionBanner(
                title: GameText.string("banner.order.filled.title", order.quantity, good),
                description: GameText.string(
                    "banner.order.filled.text",
                    name,
                    HUDViewModel.formatMoney(reward),
                    world.orders.favour.value(for: order.issuer)
                )
            ))
        case .orderFailed:
            show(SessionBanner(
                title: isCrown
                    ? GameText.string("banner.order.missed.title.crown", good)
                    : GameText.string("banner.order.missed.title.rival", good, name),
                description: isCrown
                    ? GameText.string("banner.order.missed.text.crown", order.delivered, order.quantity, order.favourLoss)
                    : GameText.string("banner.order.missed.text.rival", order.delivered, order.quantity, name, order.favourLoss)
            ))
        case .orderExpired:
            show(SessionBanner(
                title: isCrown
                    ? GameText.string("banner.order.lapsed.title.crown")
                    : GameText.string("banner.order.lapsed.title.rival", name),
                description: GameText.string("banner.order.lapsed.text")
            ))
        default:
            return
        }
    }

    /// "Steam engine" from the palette's "Steam Engine".
    static func sentenceCase(_ kind: BuildingKind) -> String {
        GameText.inSentence(BuildTool.place(kind).displayName).capitalizedFirst
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
            title: GameText.string("banner.pinch.title"),
            description: GameText.string("banner.pinch.text")
        ))
    }

    /// The event chip's tap: the warning of the event warned or under way
    /// again, or that a fire burns. Spec: `platform-shells` / Seasonal events
    /// show banners and a chip.
    public func replaySeasonalWarning(animated: Bool = true) {
        // Spec: `platform-shells`: for blight and fever the chip also shows the marked area.
        if let marked = world.seasonalEvents.marked {
            // The marked area as the map clips it, as the threat overlay draws it.
            let box = marked.around.expanded(by: marked.radius)
            let (minX, maxX) = (max(0, box.minX), min(world.mapWidth - 1, box.maxX))
            let (minY, maxY) = (max(0, box.minY), min(world.mapHeight - 1, box.maxY))
            centerCamera(onX: Double(minX + maxX + 1) / 2, y: Double(minY + maxY + 1) / 2, animated: animated)
        }
        guard let banner = seasonalChipBanner() else { return }
        // The player asked: it takes the slot at once, paused or not, and the
        // banner it interrupts comes back next.
        bannerQueue.removeAll { $0.banner == banner }
        if let shown = bannerState?.banner, isBannerShowing, shown != banner {
            bannerQueue.insert(QueuedBanner(banner: shown, isUrgent: false, expiresAtTick: nil), at: 0)
        }
        bannerState = (banner, world.tickCount + Self.bannerTicks)
    }

    /// Resume, the pause control or Esc: the simulation runs again.
    public func dismissDeficitHint() {
        deficitHint = nil
    }

    /// Spec: `platform-shells` / Deficit hint.
    private static func deficitHint(upkeep: Int64, tax: Int64) -> SessionBanner {
        SessionBanner(
            title: GameText.string("banner.deficit.title", upkeep, tax),
            description: GameText.string("banner.deficit.text")
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

    /// Road tiles short of a market's reach at which a house counts as distant.
    static let distantHouseMargin = 4

    /// The first time this session a player's house stands near the edge of
    /// its market's reach, or out of every market's reach, a banner says a
    /// marketplace near the outer houses serves them, once no other banner
    /// shows. Spec: `platform-shells` / Distant-house market hint.
    func noteDistantHouses(in snapshot: WorldSnapshot) {
        guard !hintedDistantHouses, !isBannerBusy, deficitHint == nil, !isGameOver else { return }
        let isPlayers = { (house: EntityID) in snapshot.buildings[house]?.owner == .player }
        let nearEdge = snapshot.marketServing.first { house, serving in
            let radius = snapshot.buildings[serving.hub]?.kind.hub?.radius ?? 0
            return isPlayers(house) && serving.distance >= radius - Self.distantHouseMargin
        }
        let outOfReach = snapshot.buildingIssues.contains { $0.value == .noMarketInReach && isPlayers($0.key) }
        guard nearEdge != nil || outOfReach else { return }
        hintedDistantHouses = true
        if outOfReach {
            // This banner says what the problem hint's "No market in reach" would.
            hintedProblems.insert(InspectorViewModel.problemText(.noMarketInReach))
        }
        let hub = nearEdge.flatMap { snapshot.buildings[$0.value.hub]?.kind } ?? .townCenter
        let radius = hub.hub?.radius ?? 0
        show(SessionBanner(
            title: GameText.string("banner.outgrowing.title"),
            description: GameText.string("banner.outgrowing.text", radius)
        ))
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
        SessionBanner(title: GameText.string("banner.problem.title", name), description: GameText.string("banner.problem.text", problem))
    }

    static func idleGoodHint(_ idle: IdleGood) -> SessionBanner {
        let good = GameText.inSentence(GoodsCatalog.spec(for: idle.good).displayName)
        let builds = idle.users.map { GameText.string("banner.idle.user", $0.spokenName) }
        // Not ListFormatter: its English adds a comma before "or".
        let named = builds.count < 2
            ? builds.joined()
            : builds.dropLast().joined(separator: ", ") + GameText.string("list.or") + builds[builds.count - 1]
        return SessionBanner(
            title: GameText.string("banner.idle.title", good),
            description: GameText.string("banner.idle.text", named, good)
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
        if !isQueueingTickBanners {
            showNextBanner()
        }
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

    /// Off the column, the banner sits this far above the bottom: over the
    /// build controls as measured, the open dock drawer and tool strip with them.
    static func bottomInset(controlsHeight: CGFloat) -> CGFloat {
        controlsHeight + 8
    }

    /// With a left rail an open drawer stands full height beside it, under
    /// where a wide banner would go, so the banner waits while it is open.
    static func showsWide(placement: HUDDock, drawerOpen: Bool) -> Bool {
        placement == .bottomDock || !drawerOpen
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
                    Button(GameText.string("pause.resume"), action: onResume)
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

extension GameSession {
    /// A win shows the ending card in a chapter, else the win sheet; a
    /// loss shows the lost card in a chapter.
    func noteScenarioEnd(_ event: WorldEvent) {
        switch event {
        case .scenarioWon:
            guard !noteChapterWin() else { return }
            show(SessionBanner(title: GameText.string("goals.scenarioComplete"), description: GameText.string("banner.won.text")))
            isWinSheetPresented = true
        case let .scenarioLost(reason):
            noteChapterLoss(reason)
        default:
            break
        }
    }

    /// A save that failed when leaving a chapter game, which stays open.
    func noteSaveFailure(_ error: any Error) {
        show(SessionBanner(
            title: GameText.string("banner.saveFailed.title"),
            description: GameText.string("banner.saveFailed.text", "\(error)")
        ))
    }
}
