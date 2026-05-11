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
            VStack {
                HUDFrameView(viewModel: session.hud)
                BuildPaletteView { kind in
                    session.placeAtCameraCenter(kind)
                }
            }
            .padding()
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

    /// Enqueue a place command targeted at the camera-center tile. The
    /// command applies at the next tick boundary.
    public func placeAtCameraCenter(_ kind: BuildingKind) {
        let coord = TileCoordinate(
            x: Int(world.camera.centerX.rounded()),
            y: Int(world.camera.centerY.rounded())
        )
        world.enqueue(.place(kind, at: coord))
    }

    @MainActor
    public var worldView: some View {
        let provider: @MainActor @Sendable () -> WorldSnapshot? = { [weak self] in
            self?.world.snapshot()
        }
        return SnapshotHostView(snapshotProvider: provider)
    }
}

/// Tiny indirection so CityUI does not need to know about CityRender2D's
/// view type at the public API boundary. Apps that want the SpriteKit
/// renderer wire it here.
@MainActor
struct SnapshotHostView: View {
    let snapshotProvider: @MainActor @Sendable () -> WorldSnapshot?
    var body: some View {
        SnapshotRendererRegistry.shared.makeView(snapshotProvider: snapshotProvider)
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
    public var factory: (@escaping @MainActor @Sendable () -> WorldSnapshot?) -> AnyView = { _ in
        AnyView(
            Color.black.overlay(
                Text("World renderer not registered")
                    .foregroundStyle(.white)
            )
        )
    }

    func makeView(snapshotProvider: @escaping @MainActor @Sendable () -> WorldSnapshot?) -> AnyView {
        factory(snapshotProvider)
    }
}
