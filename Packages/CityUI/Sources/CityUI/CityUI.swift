import CityCore
import Foundation
import SwiftUI

/// The top-level view shown by every app shell. Composes a snapshot-driven
/// world background with a HUD frame, a build palette, and an inspector.
///
/// State plumbing follows design D1: this view holds the only mutable World
/// reference. Renderer and HUD receive snapshots, never the model itself.
public struct CityRootView: View {
    @State private var session: GameSession

    public init(session: GameSession = GameSession()) {
        _session = State(initialValue: session)
    }

    public var body: some View {
        ZStack(alignment: .top) {
            session.worldView
                .ignoresSafeArea()
                // simultaneousGesture (vs .gesture) so the underlying
                // SpriteKit scene still receives touch / mouse events for
                // tap-tile selection. A bare .gesture(DragGesture(...))
                // claims the touch sequence and starves the scene's
                // touchesEnded / mouseUp handlers.
                .simultaneousGesture(panGesture)
                .simultaneousGesture(zoomGesture)
            VStack {
                HUDFrameView(viewModel: session.hud)
                BuildPaletteView(armed: session.selectedTool) { tool in
                    session.selectTool(tool)
                }
                if session.selectedTool != .inspect {
                    Text("Tap a tile to \(session.selectedTool.displayName.lowercased())")
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
    }

    /// One-finger drag (iOS) / left-mouse drag (Mac) pans the camera.
    /// Deltas are kept in screen pixels; the GameSession translates to
    /// tile-space via CityRender2D.InputTranslator.
    private var panGesture: some Gesture {
        DragGesture(minimumDistance: 1)
            .onChanged { value in
                session.handlePanDelta(
                    deltaX: value.translation.width - session.lastPanX,
                    deltaY: value.translation.height - session.lastPanY
                )
                session.lastPanX = value.translation.width
                session.lastPanY = value.translation.height
            }
            .onEnded { _ in
                session.lastPanX = 0
                session.lastPanY = 0
            }
    }

    /// Pinch on iOS / two-finger trackpad on Mac. SwiftUI's
    /// MagnificationGesture reports a cumulative scale factor; we apply
    /// the delta since the last reading.
    private var zoomGesture: some Gesture {
        MagnificationGesture()
            .onChanged { magnitude in
                let factor = magnitude / session.lastMagnification
                session.handlePinch(factor: factor)
                session.lastMagnification = magnitude
            }
            .onEnded { _ in
                session.lastMagnification = 1.0
            }
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

    public init(world: World = World.newGame()) {
        self.world = world
        self.hud = HUDViewModel(money: 0, population: 0)
        self.tickTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.advance()
            }
        }
    }

    private var tickTimer: Timer?

    private func advance() {
        world.tick()
        hud.apply(world.snapshot())
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
            world.enqueue(.place(kind, at: tile))
        case .demolish:
            world.enqueue(.demolish(at: tile))
        }
    }

    public var selectedTile: TileCoordinate?

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
        return SnapshotHostView(snapshotProvider: provider, tapSink: tapSink)
    }
}

/// Tiny indirection so CityUI does not need to know about CityRender2D's
/// view type at the public API boundary. Apps that want the SpriteKit
/// renderer wire it here.
@MainActor
struct SnapshotHostView: View {
    let snapshotProvider: @MainActor @Sendable () -> WorldSnapshot?
    let tapSink: @MainActor @Sendable (TileCoordinate) -> Void
    var body: some View {
        SnapshotRendererRegistry.shared.makeView(
            snapshotProvider: snapshotProvider,
            tapSink: tapSink
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

    public var factory: (@escaping SnapshotProvider, @escaping TapSink) -> AnyView = { _, _ in
        AnyView(
            Color.black.overlay(
                Text("World renderer not registered")
                    .foregroundStyle(.white)
            )
        )
    }

    func makeView(
        snapshotProvider: @escaping @MainActor @Sendable () -> WorldSnapshot?,
        tapSink: @escaping @MainActor @Sendable (TileCoordinate) -> Void
    ) -> AnyView {
        factory(snapshotProvider, tapSink)
    }
}
