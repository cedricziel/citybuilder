import CityCore
import Foundation
import SwiftUI

/// The top-level view shown by every app shell. Composes a snapshot-driven
/// world background with a HUD frame, a build palette, and an inspector.
///
/// State plumbing follows design D1: this view holds the only mutable World
/// reference. Renderer and HUD receive snapshots, never the model itself.
public struct CityRootView: View {
    @State var session: GameSession
    @State var settingsPresented: Bool = false
    @State var researchPresented: Bool = false
    @State var goalsPresented: Bool = false
    @State var pauseMenuViewModel: PauseMenuViewModel?
    let settingsContent: (() -> AnyView)?
    let pauseMenuConfig: PauseMenuConfig?

    public init(
        session: GameSession = GameSession(),
        pauseMenu: PauseMenuConfig? = nil,
        @ViewBuilder settings: @escaping () -> some View
    ) {
        _session = State(initialValue: session)
        self.settingsContent = { AnyView(settings()) }
        self.pauseMenuConfig = pauseMenu
    }

    public init(session: GameSession = GameSession(), pauseMenu: PauseMenuConfig? = nil) {
        _session = State(initialValue: session)
        self.settingsContent = nil
        self.pauseMenuConfig = pauseMenu
    }

    public var body: some View {
        @Bindable var sessionBinding = session
        return rootContent(isPaused: $sessionBinding.isPaused)
    }

    private func rootContent(isPaused isPausedBinding: Binding<Bool>) -> some View {
        ZStack(alignment: .top) {
            session.worldView
                .ignoresSafeArea()
                // simultaneousGesture (vs .gesture) so the underlying
                // SpriteKit scene still receives touch / mouse events for
                // tap-tile selection. A bare .gesture(DragGesture(...))
                // claims the touch sequence and starves the scene's
                // touchesEnded / mouseUp handlers.
                .simultaneousGesture(panGesture, including: Self.panGestureMask(for: session.selectedTool))
                .simultaneousGesture(zoomGesture)
            VStack {
                HStack {
                    HUDFrameView(viewModel: session.hud)
                    goalsButton
                    researchButton
                    pauseButton
                    if settingsContent != nil {
                        settingsButton
                    }
                }
                BuildPaletteView(armed: session.selectedTool, isLocked: session.isLocked, isHidden: session.isHidden) { tool in
                    session.selectTool(tool)
                }
                PlacementRejectionBanner(hud: session.hud)
                SessionBannerView(banner: session.banner)
                if session.selectedTool != .inspect {
                    Text(armedCaption)
                        .font(.caption2)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.thinMaterial, in: Capsule())
                }
                Spacer()
                let inspector = session.inspector
                if session.selectedTool == .inspect, !inspector.bullets.isEmpty {
                    HStack {
                        InspectorView(viewModel: inspector)
                        Spacer()
                    }
                }
            }
            .padding()
        }
        .researchSheet(isPresented: $researchPresented, session: session)
        .goalsSheets(session: session, goalsPresented: $goalsPresented, onQuitToTitle: pauseMenuConfig?.onQuitToTitle)
        .sheet(isPresented: $settingsPresented) {
            if let content = settingsContent {
                content()
            }
        }
        .sheet(
            isPresented: isPausedBinding,
            onDismiss: dismissPause,
            content: pauseMenuContent
        )
    }

    /// Caption under the build palette while a tool is armed.
    private var armedCaption: String {
        let name = session.selectedTool.displayName
        let cost = session.armedToolCost
        if cost > 0 {
            return "Tap or drag to place \(name.lowercased()) — $\(cost)"
        }
        if session.selectedTool == .demolish {
            return "Tap or drag to demolish"
        }
        return "Tap a tile to \(name.lowercased())"
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
    /// Hard pause. While `true`, `step()` short-circuits: no tick, no
    /// snapshot, no event forwarding. The audio engine is untouched so
    /// music keeps playing. Spec: `add-game-pause-menu` / `pause-menu`
    /// Requirement: Paused session does not tick the world.
    public var isPaused: Bool = false

    public init(
        world: World = World.newGame(),
        audioEventConsumer: AudioEventConsumer? = nil,
        audioSnapshotConsumer: AudioSnapshotConsumer? = nil
    ) {
        self.world = world
        self.hud = HUDViewModel(money: 0, population: 0)
        self.audioEventConsumer = audioEventConsumer
        self.audioSnapshotConsumer = audioSnapshotConsumer
        self.tickTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.step()
            }
        }
    }

    private var tickTimer: Timer?

    /// The banner on screen and the tick it hides at.
    var bannerState: (banner: SessionBanner, hidesAtTick: UInt64)?
    public var isWinSheetPresented = false

    /// Advance the simulation one tick. Drains the per-tick event stream
    /// into the registered `audioEventConsumer` (if any) and refreshes
    /// the HUD. Called by the 10 Hz timer and reachable from tests.
    /// While `isPaused == true` the call is a no-op so the world,
    /// snapshot, and audio events stay frozen.
    public func step() {
        guard !isPaused else { return }
        let result = world.tick()
        noteBannerEvents(in: result.events)
        let snapshot = world.snapshot()
        hud.apply(snapshot)
        // Push the snapshot to audio before the matching events so the
        // coordinator's primaryEntityID → tile resolution sees this tick's
        // building positions, not the prior tick's.
        audioSnapshotConsumer?(snapshot)
        audioEventConsumer?(result.events)
    }

    /// The build tool currently armed for placement / demolition. When
    /// `.inspect`, taps select the tile for the inspector. When `.place`
    /// or `.demolish`, taps enqueue the corresponding command and leave
    /// the tool armed so the player can place a run of roads or houses
    /// in a row without re-arming.
    public var selectedTool: BuildTool = .inspect

    /// Toggle a tool: tap the same palette button twice to disarm.
    public func selectTool(_ tool: BuildTool) {
        if selectedTool == tool {
            selectedTool = .inspect
        } else {
            selectedTool = tool
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
        world.enqueue(.place(kind, at: coord))
    }

    // Gesture state. SwiftUI's DragGesture reports cumulative translation;
    // we track the previous reading to derive per-frame deltas.
    public var lastPanX: CGFloat = 0
    public var lastPanY: CGFloat = 0
    public var lastMagnification: CGFloat = 1.0

    /// Iso projection constants. Kept here (rather than imported from
    /// CityRender2D) so CityUI does not depend on the renderer package.
    private static let tileWidth: Double = 64
    private static let tileHeight: Double = 32

    /// Translate a screen-space pan delta (pixels) into a tile-space
    /// camera delta and apply it.
    ///
    /// Derived from first principles:
    /// - SwiftUI DragGesture.translation: y is DOWN-positive
    /// - SpriteKit scene (and IsoMath): y is UP-positive
    /// - For the world to follow the finger, the camera must move OPPOSITE
    ///   the finger by the same screen amount. In scene-y-up coords:
    ///       camera_dx_scene = -dxScreen
    ///       camera_dy_scene = +dyScreen   (sign flip because of y-down → y-up)
    /// - Inverting the iso projection (screen.x = (col-row)·halfW,
    ///   scene.y = -(col+row)·halfH):
    ///       dCol - dRow =  camera_dx_scene / halfW = -dxScreen / halfW
    ///       dCol + dRow = -camera_dy_scene / halfH = -dyScreen / halfH
    ///   →   dCol = -(dxScreen/tileWidth + dyScreen/tileHeight) / zoom
    ///       dRow =  (dxScreen/tileWidth - dyScreen/tileHeight) / zoom
    ///
    /// Concrete check: drag up by 32 px (dyScreen = -32) yields dCol = +1,
    /// dRow = +1, so the camera's (col, row) both increase, scene-y
    /// decreases, camera moves DOWN in scene, content shifts UP — which is
    /// "drag up → scroll down" in scroll-bar parlance.
    public func handlePanDelta(deltaX: CGFloat, deltaY: CGFloat) {
        let zoom = max(world.camera.zoom, 0.0001)
        let dxOverW = Double(deltaX) / Self.tileWidth
        let dyOverH = Double(deltaY) / Self.tileHeight
        let dCol = -(dxOverW + dyOverH) / zoom
        let dRow = (dxOverW - dyOverH) / zoom
        world.camera.pan(deltaX: dCol, deltaY: dRow)
    }

    /// Apply a pinch factor (relative to last reading) to the zoom.
    public func handlePinch(factor: CGFloat) {
        world.camera.multiplyZoom(by: Double(factor))
    }

    /// Tap at a tile coordinate. Behavior depends on the armed tool:
    /// - .inspect (default): select the tile for the inspector.
    /// - .place(kind): enqueue a `.place` command. Tool stays armed so
    ///   the player can place a run of roads or houses without re-arming.
    /// - .demolish: enqueue a `.demolish` command.
    public func handleTap(at tile: TileCoordinate) {
        switch selectedTool {
        case .inspect:
            selectedTile = tile
        case let .place(kind):
            if case let .rejected(reason) = world.canPlace(kind, at: tile) {
                hud.showRejection(reason, now: Date())
                return
            }
            world.enqueue(.place(kind, at: tile))
        case .demolish:
            world.enqueue(.demolish(at: tile))
        }
    }

    public var selectedTile: TileCoordinate?

    /// Tile currently under the pointer / fingertip. Drives the ghost
    /// preview. nil when no hover position is known (e.g. on iPhone
    /// before a drag starts, or when the pointer leaves the world view).
    public var hoveredTile: TileCoordinate?

    /// Apply a hover update from the renderer. `nil` clears the hover.
    public func handleHover(at tile: TileCoordinate?) {
        hoveredTile = tile
    }

    /// Apply a drag update. While a build tool is armed, this is the
    /// "paint" pathway — every new tile under the finger gets a place /
    /// demolish command enqueued. In inspect mode, drag is a no-op (pan
    /// camera handles the gesture instead).
    public func handleDrag(at tile: TileCoordinate) {
        switch selectedTool {
        case .inspect:
            return
        case let .place(kind):
            world.enqueue(.place(kind, at: tile))
        case .demolish:
            world.enqueue(.demolish(at: tile))
        }
    }

    /// Ghost preview state derived from the armed tool + hovered tile.
    /// `valid` runs the same canPlace check the simulation will use at
    /// the tick boundary, so the green / red tint matches reality.
    public func ghostState() -> GhostPreview? {
        guard let tile = hoveredTile else { return nil }
        switch selectedTool {
        case .inspect, .demolish:
            return nil
        case let .place(kind):
            let valid: Bool
            if case .allowed = world.canPlace(kind, at: tile) {
                let spec = BuildingCatalog.spec(for: kind)
                valid = world.economy.balance >= spec.cost
            } else {
                valid = false
            }
            return GhostPreview(
                kind: kind, tile: tile, valid: valid,
                costBreakdown: costBreakdown(for: kind, anchor: tile)
            )
        }
    }

    private func costBreakdown(
        for kind: BuildingKind,
        anchor: TileCoordinate
    ) -> [Good: GhostCost]? {
        let spec = BuildingCatalog.spec(for: kind)
        guard !spec.materialCost.isEmpty else { return nil }
        let tileToIsland = world.tileToIslandMap()
        let available = world.islandStockpile(at: anchor, tileToIsland: tileToIsland)
        let islandID = tileToIsland[anchor]
        var breakdown: [Good: GhostCost] = [:]
        for (good, need) in spec.materialCost {
            let have = available[good] ?? 0
            let status = statusFor(
                need: need, have: have,
                good: good, islandID: islandID,
                tileToIsland: tileToIsland
            )
            breakdown[good] = GhostCost(need: need, have: have, status: status)
        }
        return breakdown
    }

    private func statusFor(
        need: Int,
        have: Int,
        good: Good,
        islandID: IslandID?,
        tileToIsland: [TileCoordinate: IslandID]
    ) -> CostStatus {
        if have >= need { return .ok }
        guard let islandID else { return .blocked }
        let supplied = world.producesGood(
            onIsland: islandID, good: good, tileToIsland: tileToIsland
        )
        return supplied ? .queueable : .blocked
    }

    public struct GhostPreview: Equatable, Sendable {
        public let kind: BuildingKind
        public let tile: TileCoordinate
        public let valid: Bool
        /// Per-good `(need, have)` pair for the armed building on the
        /// hovered island. Nil when the building is free of materials
        /// (road, town center) — the cost row hides entirely. The view
        /// renders a chip per entry; goods where `have < need` paint
        /// red.
        public let costBreakdown: [Good: GhostCost]?

        public init(
            kind: BuildingKind,
            tile: TileCoordinate,
            valid: Bool,
            costBreakdown: [Good: GhostCost]? = nil
        ) {
            self.kind = kind
            self.tile = tile
            self.valid = valid
            self.costBreakdown = costBreakdown
        }

        /// View-helper: `isShort(.wood, in: breakdown)` returns true
        /// when the chip should render in the destructive style.
        public static func isShort(_ good: Good, in breakdown: [Good: GhostCost]) -> Bool {
            (breakdown[good]?.isShort) ?? false
        }
    }

    /// Cost of the currently-armed building (0 if no place tool armed).
    public var armedToolCost: Int64 {
        if case let .place(kind) = selectedTool {
            return BuildingCatalog.spec(for: kind).cost
        }
        return 0
    }

    /// Inspector model derived from the current snapshot + selection.
    public var inspector: InspectorViewModel {
        guard let selectedTile else { return InspectorViewModel(bullets: []) }
        return InspectorViewModel.make(
            from: world.snapshot(),
            tile: selectedTile,
            buildings: world.buildings
        )
    }

    @MainActor
    public var worldView: some View {
        let provider: @MainActor @Sendable () -> WorldSnapshot? = { [weak self] in
            self?.world.snapshot()
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
        let ghostProvider: @MainActor @Sendable () -> GameSession.GhostPreview? = { [weak self] in
            self?.ghostState()
        }
        return SnapshotHostView(
            snapshotProvider: provider,
            tapSink: tapSink,
            dragSink: dragSink,
            hoverSink: hoverSink,
            ghostProvider: ghostProvider
        )
    }
}

/// Tiny indirection so CityUI does not need to know about CityRender2D's
/// view type at the public API boundary. Apps that want the SpriteKit
/// renderer wire it here.
@MainActor
struct SnapshotHostView: View {
    let snapshotProvider: @MainActor @Sendable () -> WorldSnapshot?
    let tapSink: @MainActor @Sendable (TileCoordinate) -> Void
    let dragSink: @MainActor @Sendable (TileCoordinate) -> Void
    let hoverSink: @MainActor @Sendable (TileCoordinate?) -> Void
    let ghostProvider: @MainActor @Sendable () -> GameSession.GhostPreview?
    var body: some View {
        SnapshotRendererRegistry.shared.makeView(
            snapshotProvider: snapshotProvider,
            tapSink: tapSink,
            dragSink: dragSink,
            hoverSink: hoverSink,
            ghostProvider: ghostProvider
        )
    }
}

/// Plug-in point so the renderer package can register itself without
/// CityUI directly depending on it. App shells call
/// `SnapshotRendererRegistry.shared.factory = …` at launch.
///
/// MainActor-isolated because the factory produces SwiftUI views and is
/// only meant to be touched from the main thread.
@MainActor
public final class SnapshotRendererRegistry {
    public static let shared = SnapshotRendererRegistry()

    /// Returns a SwiftUI view that draws the world from the given snapshot
    /// provider. Default is a placeholder text view; CityRender2D registers
    /// a real implementation on app launch.
    public typealias SnapshotProvider = @MainActor @Sendable () -> WorldSnapshot?
    public typealias TapSink = @MainActor @Sendable (TileCoordinate) -> Void
    public typealias DragSink = @MainActor @Sendable (TileCoordinate) -> Void
    public typealias HoverSink = @MainActor @Sendable (TileCoordinate?) -> Void
    public typealias GhostProvider = @MainActor @Sendable () -> GameSession.GhostPreview?

    public var factory: (
        @escaping SnapshotProvider,
        @escaping TapSink,
        @escaping DragSink,
        @escaping HoverSink,
        @escaping GhostProvider
    ) -> AnyView = { _, _, _, _, _ in
        AnyView(
            Color.black.overlay(
                Text("World renderer not registered")
                    .foregroundStyle(.white)
            )
        )
    }

    func makeView(
        snapshotProvider: @escaping SnapshotProvider,
        tapSink: @escaping TapSink,
        dragSink: @escaping DragSink,
        hoverSink: @escaping HoverSink,
        ghostProvider: @escaping GhostProvider
    ) -> AnyView {
        factory(snapshotProvider, tapSink, dragSink, hoverSink, ghostProvider)
    }
}
