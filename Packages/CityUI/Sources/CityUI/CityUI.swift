import CityCore
import Foundation
import QuartzCore
import SwiftUI

/// The top-level view shown by every app shell. Composes a snapshot-driven
/// world background with a HUD frame, a build palette, and an inspector.
///
/// State plumbing follows design D1: this view holds the only mutable World
/// reference. Renderer and HUD receive snapshots, never the model itself.
public struct CityRootView: View {
    @State var session: GameSession
    @State var settingsPresented: Bool = false
    /// The build controls' measured height, which a full-width banner clears.
    @State var bottomControlsHeight: CGFloat = 0
    @State var researchPresented: Bool = false
    @State var goalsPresented: Bool = false
    @State var standingsPresented: Bool = false
    @State var routesPresented: Bool = false
    @State var pauseMenuViewModel: PauseMenuViewModel?
    @State var buildRail = BuildRailModel()
    @State var inspectorExpanded = false
    @AppStorage var showsMinimap: Bool
    let settingsContent: (() -> AnyView)?
    let pauseMenuConfig: PauseMenuConfig?
    #if os(macOS)
    @Environment(\.openSettings) var openSettingsScene
    #endif
    #if os(tvOS)
    @State var tvRemote: TVRemoteController?
    #endif

    public init(
        session: GameSession = GameSession(),
        pauseMenu: PauseMenuConfig? = nil,
        @ViewBuilder settings: @escaping () -> some View
    ) {
        _session = State(initialValue: session)
        _showsMinimap = MinimapPreference.storage(idiom: HUDMetrics.idiom)
        self.settingsContent = { AnyView(settings()) }
        self.pauseMenuConfig = pauseMenu
    }

    public init(session: GameSession = GameSession(), pauseMenu: PauseMenuConfig? = nil) {
        _session = State(initialValue: session)
        _showsMinimap = MinimapPreference.storage(idiom: HUDMetrics.idiom)
        self.settingsContent = nil
        self.pauseMenuConfig = pauseMenu
    }

    public var body: some View {
        @Bindable var sessionBinding = session
        return rootContent(isPaused: $sessionBinding.isPaused)
    }

    private func rootContent(isPaused isPausedBinding: Binding<Bool>) -> some View {
        ZStack(alignment: .top) {
            withMapGestures(session.worldView.ignoresSafeArea())
            inspectorCallout
                #if os(tvOS)
                .modifier(TVHUDCommands(root: self, isInspector: true))
                #endif
            AreaCountCapsule(session: session, idiom: HUDMetrics.idiom)
            GeometryReader { proxy in
                let layout = HUDMetrics.layout(for: proxy.size)
                let insets = proxy.safeAreaInsets
                hudLayer(layout: layout, hudWidth: proxy.size.width - layout.margin * 2, worldViewSize: CGSize(
                    width: proxy.size.width + insets.leading + insets.trailing,
                    height: proxy.size.height + insets.top + insets.bottom
                ), insets: insets)
                    .padding(layout.margin)
                    .onChange(of: layout, initial: true) {
                        session.ordersReplaceInspector = OrderBoardLayout.replacesInspector(layout: layout)
                    }
                    .ordersSheet(
                        session: session,
                        presentation: OrderBoardLayout.presentation(
                            in: CGSize(
                                width: proxy.size.width + insets.leading + insets.trailing,
                                height: proxy.size.height + insets.top + insets.bottom
                            ),
                            insets: insets, layout: layout, showsMinimap: showsCornerMinimap,
                            showsFirstSteps: session.firstStepsGuide != nil
                        )
                    )
                    #if os(tvOS)
                    .modifier(TVHUDCommands(root: self))
                    #endif
            }
            touchPlacementHUD
                .zIndex(1)
            #if os(tvOS)
            TVMapOverviewView(session: session)
                .zIndex(2)
            #endif
        }
        .onChange(of: isAnySheetPresented) { _, presented in
            if presented { buildRail.close() }
        }
        .touchPlacementDialogs(session: session)
        .researchSheet(isPresented: $researchPresented, session: session)
        .goalsSheets(session: session, goalsPresented: $goalsPresented, onQuitToTitle: pauseMenuConfig?.onQuitToTitle)
        .standingsSheet(session: session, isPresented: $standingsPresented)
        .statisticsSheet(session: session)
        .chapterCardSheet(session: session)
        .routesSheet(session: session, isPresented: $routesPresented)
        .settingsSheet(isPresented: settingsBinding(whilePaused: false), content: settingsContent)
        .sheet(
            isPresented: isPausedBinding,
            onDismiss: dismissPause,
            content: {
                // Settings chosen in the pause menu opens over it, so
                // closing Settings returns to the menu.
                pauseMenuContent().hudSheetDetents()
                    .settingsSheet(isPresented: settingsBinding(whilePaused: true), content: settingsContent)
            }
        )
    }

    var isAnySheetPresented: Bool {
        settingsPresented || researchPresented || goalsPresented || standingsPresented || routesPresented
            || session.isStatisticsPresented || session.isPaused || session.isWinSheetPresented || session.chapterCard != nil
    }
}

/// Owns the live World and exposes snapshots + HUD bindings to the views.
/// Marked @Observable so SwiftUI rebinds when the HUD numbers move.
/// MainActor-isolated because the timer-driven `advance()` mutates state
/// that SwiftUI reads on the main thread.
@MainActor
@Observable
public final class GameSession {
    public var world: World
    /// This session's identity for the views that show it. Unlike the
    /// object's address, it is never reused by a later session.
    public let instanceID = UUID()

    public let hud: HUDViewModel
    /// Optional sink for the per-tick `WorldEvent` stream. When non-nil,
    /// every tick's events are forwarded after the snapshot is applied.
    /// Per spec `audio-playback` "AudioCoordinator consumes per-tick events".
    public var audioEventConsumer: AudioEventConsumer?
    /// Optional sink for the per-tick `WorldSnapshot`. When non-nil, the
    /// session pushes each tick's snapshot to the audio layer before the
    /// matching events, so the coordinator can resolve entity positions
    /// for spatial playback. Per spec `audio-playback` "Cue dispatched
    /// with optional position".
    public var audioSnapshotConsumer: AudioSnapshotConsumer?
    /// Called once when the player leaves this game, so the audio layer
    /// can silence the game's loops. Spec: `audio-playback` / A session's
    /// loops end with it.
    public var onEnd: (@MainActor () -> Void)?
    /// Hard pause. While `true`, `step()` short-circuits: no tick, no
    /// snapshot, no event forwarding. The audio engine is untouched so
    /// music keeps playing. Spec: `add-game-pause-menu` / `pause-menu`
    /// Requirement: Paused session does not tick the world.
    public var isPaused: Bool = false

    /// Ticks per timer firing. Session state, never saved.
    public var speed: GameSpeed = .normal
    /// Route mode's view-model; non-nil while the player authors a route.
    public var routeAuthoring: RouteAuthoringViewModel?
    /// The route list; its selection drives the map's route overlay.
    public let routeList = RouteListViewModel()
    /// The minimap's terrain image and markers. Spec: `platform-shells` / Minimap.
    public let minimap = MinimapModel()
    /// A minimap tap's camera move in progress; a pan stops it.
    public internal(set) var cameraGlide: CameraGlide?
    /// The Apple TV map overview while it is open.
    public internal(set) var overview: MapOverview?

    /// Ends the game: runs `onEnd` once. The title screen calls this when
    /// it drops the session.
    public func end() {
        let handler = onEnd
        onEnd = nil
        handler?()
    }

    public init(
        world: World = World.newGame(),
        audioEventConsumer: AudioEventConsumer? = nil,
        audioSnapshotConsumer: AudioSnapshotConsumer? = nil
    ) {
        self.world = world
        self.hud = HUDViewModel(money: 0, population: 0)
        self.audioEventConsumer = audioEventConsumer
        self.audioSnapshotConsumer = audioSnapshotConsumer
        routeList.commandSink = { [weak self] in self?.enqueue($0) }
        minimap.apply(world.snapshot())
        minimap.camera = world.camera
        // A save in the red emits no warning on load (`deficit-hint` D2).
        if world.economy.balance < 0, !world.economy.gameOver {
            showDeficitHint()
        }
        refreshFirstSteps()
        self.tickTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.timerFired()
            }
        }
    }

    private var tickTimer: Timer?

    /// The banner on screen and the tick it hides at.
    var bannerState: (banner: SessionBanner, hidesAtTick: UInt64)?
    /// Banners waiting their turn, urgent ones ("Fire!") first.
    var bannerQueue: [QueuedBanner] = []
    /// True while a tick's events queue their banners, so the slot goes to
    /// the most urgent of them, not the first.
    var isQueueingTickBanners = false
    /// True once this session showed the deficit hint (`deficit-hint` D2).
    var hasShownDeficitHint = false
    /// The deficit hint while it shows; the simulation waits for the
    /// player to dismiss it (`deficit-hint` D1).
    public internal(set) var deficitHint: SessionBanner?
    /// The player hid the first-hour guide, or met every step, this
    /// session (`first-hour-guidance` D2).
    var isFirstStepsDismissed = false
    /// Goods the idle-good hint has named this session.
    var hintedIdleGoods: Set<Good> = []
    /// The session came from a new game, so its first screen may offer the pinch hint once.
    public internal(set) var offersPinchHint = false
    /// Problems the building-problem hint has named this session, by their text.
    var hintedProblems: Set<String> = []
    /// What each building with a status icon is waiting on and since which tick, so a problem that
    /// the next tap would fix stays unnamed.
    var problemsSeen: [EntityID: (text: String, since: UInt64)] = [:]
    /// First steps met so far this session; a met step stays met.
    var firstStepsMet: Set<FirstStepsGuide.Step> = []
    /// The first-hour guide while it shows, refreshed every tick.
    var firstStepsGuide: FirstStepsGuide?
    public var isWinSheetPresented = false
    /// The chapter this game plays, its card, its progress record and the
    /// title screen's card actions (`GameSession+Chapter.swift`).
    public var chapter: Chapter?
    public internal(set) var chapterCard: ChapterCard?
    public var campaignProgress: CampaignProgressModel?
    public var onChapterAction: (@MainActor (ChapterAction) -> Void)?
    /// The Statistics sheet is open. Session state, never saved.
    public var isStatisticsPresented = false
    /// The order board is open. Session state, never saved.
    public var isOrdersPresented = false
    /// Where the board and the inspector callout cannot share the screen
    /// (a compact width), opening one closes the other. The root view sets
    /// it from the layout. Spec: `platform-shells` / Order board layout.
    public var ordersReplaceInspector = false
    /// The Statistics sheet's open tab, kept between openings.
    public var statisticsTab: StatisticsModel.Tab = .goods

    /// Advance the simulation one tick. Drains the per-tick event stream
    /// into the registered `audioEventConsumer` (if any) and refreshes
    /// the HUD. Called by the 10 Hz timer and reachable from tests.
    /// While `isPaused == true` the call is a no-op so the world,
    /// snapshot, and audio events stay frozen.
    public func step() {
        guard !isPaused, deficitHint == nil, chapterCard == nil else { return }
        let result = world.tick()
        noteBannerEvents(in: result.events)
        refreshFirstSteps()
        noteIdleGoods()
        let snapshot = world.snapshot()
        noteBuildingProblems(in: snapshot)
        hud.apply(snapshot)
        routeList.snapshot = snapshot
        routeAuthoring?.snapshot = snapshot
        minimap.apply(snapshot)
        // Push the snapshot to audio before the matching events so the
        // coordinator's primaryEntityID → tile resolution sees this tick's
        // building positions, not the prior tick's.
        audioSnapshotConsumer?(snapshot)
        audioEventConsumer?(result.events)
    }

    /// One firing of the 10 Hz timer: `speed` ticks.
    public func timerFired() {
        for _ in 0 ..< speed.rawValue {
            step()
        }
    }

    /// The build tool currently armed for placement / demolition. When
    /// `.inspect`, taps select the tile for the inspector. When `.place`
    /// or `.demolish`, taps enqueue the corresponding command and leave
    /// the tool armed so the player can place a run of roads or houses
    /// in a row without re-arming.
    public var selectedTool: BuildTool = .inspect {
        didSet { isPaintingRoad = false }
    }

    /// Apple TV road painting: select toggles it while the road tool is
    /// armed. Design D6.
    public var isPaintingRoad = false

    /// The tool taps and drags act with: inspect once the game is over.
    var activeTool: BuildTool {
        isGameOver ? .inspect : selectedTool
    }

    /// Queues a player command, or drops it once the game is over. Spec:
    /// `platform-shells` / Game-over banner and tools.
    func enqueue(_ command: Command) {
        guard !isGameOver else { return }
        world.enqueue(command)
    }

    /// The player pauses or resumes: the pause button, the pause hotkeys,
    /// or the Apple TV Menu button. Only these make the toggle sound, not
    /// a pause the game makes itself. Spec: `platform-shells` / Interface
    /// actions make a sound.
    public func togglePause() {
        if deficitHint != nil {
            dismissDeficitHint()
        } else {
            isPaused.toggle()
        }
        UISounds.play(.toggle)
    }

    /// The player pauses (the Apple TV Menu button); no-op when paused.
    public func pauseByPlayer() {
        guard !isPaused else { return }
        togglePause()
    }

    /// Toggle a tool: tap the same palette button twice to disarm.
    public func selectTool(_ tool: BuildTool) {
        guard !isGameOver || tool == .inspect else { return }
        UISounds.play(.select)
        if selectedTool == tool {
            selectedTool = .inspect
        } else {
            selectedTool = tool
            if tool != .inspect {
                selectedTile = nil
            }
        }
    }

    public func clearTool() {
        selectedTool = .inspect
    }

    /// Place the armed building at the camera-center tile. Useful for
    /// keyboard-driven flows and tests; the main interaction is
    /// tap-on-tile through `handleTap`.
    public func placeAtCameraCenter(_ kind: BuildingKind) {
        let coord = TileCoordinate(
            x: Int(world.camera.centerX.rounded()),
            y: Int(world.camera.centerY.rounded())
        )
        enqueue(.place(kind, at: coord))
    }

    // Gesture state. SwiftUI's DragGesture reports cumulative translation;
    // we track the previous reading to derive per-frame deltas.
    public var lastPanX: CGFloat = 0
    public var lastPanY: CGFloat = 0
    public var lastMagnification: CGFloat = 1.0

    /// Tap at a tile coordinate. Behavior depends on the armed tool:
    /// - .inspect (default): select the tile for the inspector.
    /// - .place(kind): enqueue a `.place` command. Tool stays armed so
    ///   the player can place a run of roads or houses without re-arming.
    ///   On iOS a building other than a road starts a pending placement
    ///   instead (see `confirmsBuildingPlacement`).
    /// - .demolish: enqueue a `.demolish` command.
    /// Ignored while a placement is pending.
    public func handleTap(at tile: TileCoordinate) {
        guard pendingPlacement == nil else { return }
        if routeAuthoring != nil { return handleRouteTap(at: tile) }
        switch activeTool {
        case .inspect:
            UISounds.play(.tap)
            selectedTile = tile
        case let .place(kind) where needsConfirmation(kind):
            beginPendingPlacement(kind: kind, at: tile)
        case let .place(kind):
            if case let .rejected(reason) = world.canPlace(kind, at: tile) {
                hud.showRejection(reason, in: world, now: Date())
                UISounds.play(.reject)
                return
            }
            enqueue(.place(kind, at: tile))
        case .demolish:
            enqueue(.demolish(at: tile))
        }
    }

    public var selectedTile: TileCoordinate? {
        didSet {
            if selectedTile != nil, ordersReplaceInspector { isOrdersPresented = false }
        }
    }

    /// The building the player is positioning before committing it.
    /// Transient: never saved. Spec: `rendering-2_5d` / Placement HUD.
    public var pendingPlacement: PendingPlacement?

    /// Set by a long-press; the iOS shell shows the tile menu while non-nil.
    public var tileMenuRequest: TileMenuRequest?

    /// Whether a building other than a road waits for a confirmation
    /// instead of committing on tap. On by default on iOS and Apple TV; macOS
    /// keeps commit-on-click. A flag rather than `#if` so the touch flow
    /// is testable on the Mac.
    public var confirmsBuildingPlacement: Bool = {
        #if os(iOS) || os(tvOS)
        true
        #else
        false
        #endif
    }()

    /// Keeps the camera center on the map after every camera move, so
    /// the remote's reticle never leaves it. On by default on Apple TV
    /// only. Spec: `tv-remote-controls` / Reticle marks the target tile.
    public var clampsCameraToMap: Bool = {
        #if os(tvOS)
        true
        #else
        false
        #endif
    }()

    /// Tile currently under the pointer / fingertip. Drives the ghost
    /// preview. nil when no hover position is known (e.g. on iPhone
    /// before a drag starts, or when the pointer leaves the world view).
    public var hoveredTile: TileCoordinate?

    /// The last area of effect asked for, kept for the tick it was asked
    /// on. The scene and the count capsule both ask every frame.
    @ObservationIgnored var areaOfEffectCache: AreaOfEffectCache?

    /// Apply a hover update from the renderer. `nil` clears the hover.
    public func handleHover(at tile: TileCoordinate?) {
        hoveredTile = tile
    }

    /// Apply a drag update. While a build tool is armed, this is the
    /// "paint" pathway — every new tile under the finger gets a place /
    /// demolish command enqueued. In inspect mode, drag is a no-op (pan
    /// camera handles the gesture instead).
    public func handleDrag(at tile: TileCoordinate) {
        guard pendingPlacement == nil else { return }
        switch activeTool {
        case .inspect:
            return
        case let .place(kind) where needsConfirmation(kind):
            return
        case let .place(kind):
            enqueue(.place(kind, at: tile))
        case .demolish:
            enqueue(.demolish(at: tile))
        }
    }

    @MainActor
    public var worldView: some View {
        // The renderer pulls a snapshot every frame: the minimap's glide
        // and camera follow on the same clock.
        let provider: @MainActor @Sendable () -> WorldSnapshot? = { [weak self] in
            self?.frameWillRender(now: CACurrentMediaTime())
            return self?.world.snapshot()
        }
        let tapSink: @MainActor @Sendable (TileCoordinate) -> Void = { [weak self] tile in
            self?.handleTap(at: tile)
        }
        let dragSink: @MainActor @Sendable (TileCoordinate) -> Void = { [weak self] tile in
            self?.handleDrag(at: tile)
        }
        let hoverSink: @MainActor @Sendable (TileCoordinate?) -> Void = { [weak self] tile in
            self?.handleHover(at: tile)
        }
        let longPressSink: @MainActor @Sendable (TileCoordinate) -> Void = { [weak self] tile in
            self?.handleLongPress(at: tile)
        }
        let ghostProvider: @MainActor @Sendable () -> GameSession.GhostPreview? = { [weak self] in
            self?.ghostState()
        }
        return SnapshotHostView(
            snapshotProvider: provider,
            tapSink: tapSink,
            dragSink: dragSink,
            hoverSink: hoverSink,
            longPressSink: longPressSink,
            ghostProvider: ghostProvider,
            selectionProvider: { [weak self] in self?.inspectedTile },
            // The tool `handleTap` uses (Inspect once the game is over), and not while authoring a route.
            inspectingProvider: { [weak self] in self?.activeTool == .inspect && self?.routeAuthoring == nil },
            areaOfEffectProvider: { [weak self] in self?.areaOfEffect() },
            routeOverlayProvider: { [weak self] in self?.routeOverlay() }
        )
    }
}
