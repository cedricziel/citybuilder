import CityCore
import SwiftUI

/// iOS-only views for the touch-first placement flow: the nudge HUD, the
/// tile menu dialog and the first-run hint. macOS keeps palette, hover and
/// click, so on the Mac every entry point here renders nothing.
/// Spec: `rendering-2_5d` / Placement HUD, Tile context menu on long-press.
extension CityRootView {
    /// The nudge arrows and checkmark. A sibling of the world view inside
    /// the root `ZStack` so both share the full-screen coordinate space.
    @ViewBuilder
    var touchPlacementHUD: some View {
        #if os(iOS)
        PlacementHUDOverlay(session: session)
        #else
        EmptyView()
        #endif
    }

    /// "Actions" in the inspector callout: the same menu as a long-press, for
    /// players who never find the gesture.
    @ViewBuilder
    var inspectorActionsButton: some View {
        #if os(iOS)
        if let tile = session.selectedTile {
            Button("Actions") {
                session.tileMenuRequest = TileMenuRequest(tile: tile)
            }
        }
        #else
        EmptyView()
        #endif
    }
}

extension View {
    /// Attaches the tile menu dialog and the first-run hint on iOS.
    @ViewBuilder
    func touchPlacementDialogs(session: GameSession) -> some View {
        #if os(iOS)
        modifier(TouchPlacementDialogs(session: session))
        #else
        self
        #endif
    }
}

#if os(iOS)
private struct TouchPlacementDialogs: ViewModifier {
    let session: GameSession
    private let coachmarks: CoachmarkStore
    @State private var hintVisible: Bool

    init(session: GameSession) {
        let coachmarks = CoachmarkStore()
        self.session = session
        self.coachmarks = coachmarks
        _hintVisible = State(initialValue: coachmarks.shouldShowTouchPlacementHint)
    }

    func body(content: Content) -> some View {
        content
            .confirmationDialog(
                "Tile actions",
                isPresented: Binding(
                    get: { session.tileMenuRequest != nil },
                    set: { if !$0 { session.tileMenuRequest = nil } }
                ),
                titleVisibility: .hidden,
                presenting: session.tileMenuRequest
            ) { request in
                ForEach(session.tileMenuViewModel(for: request.tile).items, id: \.self) { item in
                    menuButton(item, tile: request.tile)
                }
            }
            .overlay(alignment: .bottom) {
                if hintVisible, session.pendingPlacement == nil {
                    CoachmarkView {
                        coachmarks.dismissTouchPlacementHint()
                        hintVisible = false
                    }
                }
            }
    }

    @ViewBuilder
    private func menuButton(_ item: TileMenuItem, tile: TileCoordinate) -> some View {
        switch item {
        case let .build(kind, enabled, _):
            Button(item.title) { session.applyMenuChoice(.build(kind), at: tile) }
                .disabled(!enabled)
        case .demolish:
            Button(item.title, role: .destructive) { session.applyMenuChoice(.demolish, at: tile) }
        case .dismiss:
            Button(item.title, role: .cancel) { session.applyMenuChoice(.dismiss, at: tile) }
        }
    }
}

private struct CoachmarkView: View {
    let dismiss: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "hand.tap")
            Text("Long-press a tile to build")
                .font(.callout)
            Button("Got it", action: dismiss)
                .buttonStyle(.borderedProminent)
        }
        .padding(12)
        .background(.thinMaterial, in: Capsule())
        .padding(.bottom, 24)
    }
}

private struct PlacementHUDOverlay: View {
    let session: GameSession

    var body: some View {
        if let hud = session.placementHUD {
            GeometryReader { proxy in
                let center = PlacementHUDLayout.viewPoint(
                    forTile: hud.anchor, camera: session.world.camera, viewSize: proxy.size
                )
                ZStack {
                    ForEach(hud.arrows, id: \.self) { direction in
                        let offset = PlacementHUDLayout.arrowOffset(for: direction)
                        hudButton(Self.symbol(for: direction), label: "Move \(direction)") {
                            hud.nudge(direction)
                        }
                        .disabled(!hud.isEnabled(direction))
                        .position(x: center.x + offset.width, y: center.y + offset.height)
                    }
                    // Confirm and cancel sit side by side under the ghost so
                    // the building being placed stays visible.
                    let below = center.y + PlacementHUDLayout.arrowRadius + PlacementHUDLayout.actionGap
                    hudButton("checkmark", label: "Place", tint: hud.isValid ? .green : .orange, action: hud.confirm)
                        .position(x: center.x + PlacementHUDLayout.actionGap, y: below)
                    hudButton("xmark", label: "Cancel", tint: .red, action: hud.cancel)
                        .position(x: center.x - PlacementHUDLayout.actionGap, y: below)
                }
            }
            .ignoresSafeArea()
        }
    }

    private static func symbol(for direction: NudgeDirection) -> String {
        switch direction {
        case .ne: "arrow.up.right"
        case .se: "arrow.down.right"
        case .sw: "arrow.down.left"
        case .nw: "arrow.up.left"
        }
    }

    private func hudButton(
        _ symbol: String,
        label: String,
        tint: Color = .accentColor,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.title3.weight(.bold))
                .frame(width: PlacementHUDLayout.buttonSize, height: PlacementHUDLayout.buttonSize)
                .background(.thinMaterial, in: Circle())
                .overlay(Circle().stroke(tint, lineWidth: 2))
                .foregroundStyle(tint)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}
#endif
