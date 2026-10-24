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
    let longPressSink: @MainActor @Sendable (TileCoordinate) -> Void
    let ghostProvider: @MainActor @Sendable () -> GameSession.GhostPreview?
    let selectionProvider: @MainActor @Sendable () -> TileCoordinate?
    let areaOfEffectProvider: @MainActor @Sendable () -> AreaOfEffect?
    let routeOverlayProvider: @MainActor @Sendable () -> RouteOverlay?
    var body: some View {
        if let factory = SnapshotRendererRegistry.shared.factory {
            factory(
                snapshotProvider, tapSink, dragSink, hoverSink, longPressSink, ghostProvider, selectionProvider,
                areaOfEffectProvider, routeOverlayProvider
            )
        } else {
            Color.black.overlay(
                Text("World renderer not registered")
                    .foregroundStyle(.white)
            )
        }
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
    /// provider. CityRender2D registers a real implementation on app launch.
    public typealias SnapshotProvider = @MainActor @Sendable () -> WorldSnapshot?
    public typealias TapSink = @MainActor @Sendable (TileCoordinate) -> Void
    public typealias DragSink = @MainActor @Sendable (TileCoordinate) -> Void
    public typealias HoverSink = @MainActor @Sendable (TileCoordinate?) -> Void
    public typealias LongPressSink = @MainActor @Sendable (TileCoordinate) -> Void
    public typealias GhostProvider = @MainActor @Sendable () -> GameSession.GhostPreview?
    /// The inspected tile, so the scene can ring a selected signature
    /// building.
    public typealias SelectionProvider = @MainActor @Sendable () -> TileCoordinate?
    /// What the ghost or the selected building reaches. Spec:
    /// `rendering-2_5d` / Areas of effect while placing and selecting.
    public typealias AreaOfEffectProvider = @MainActor @Sendable () -> AreaOfEffect?
    /// The route the scene draws. Spec: `rendering-2_5d` / Route overlay
    /// from the session.
    public typealias RouteOverlayProvider = @MainActor @Sendable () -> RouteOverlay?

    public typealias Factory = (
        @escaping SnapshotProvider,
        @escaping TapSink,
        @escaping DragSink,
        @escaping HoverSink,
        @escaping LongPressSink,
        @escaping GhostProvider,
        @escaping SelectionProvider,
        @escaping AreaOfEffectProvider,
        @escaping RouteOverlayProvider
    ) -> AnyView

    /// The registered renderer; nil until an app registers one, so tests
    /// and previews can draw a stand-in.
    public var factory: Factory?
}
