import CityCore
import SwiftUI

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
