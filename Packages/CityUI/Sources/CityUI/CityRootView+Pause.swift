import CityCore
import SwiftUI

/// Pause-menu view helpers split out of `CityRootView` so the main
/// file stays under SwiftLint's 500-line ceiling. Spec:
/// `add-game-pause-menu` / `pause-menu` (pause sheet + HUD button).
extension CityRootView {
    /// The menu buttons in one row at the top right: goals, research,
    /// standings, statistics and routes when they apply, then settings.
    var menuButtons: some View {
        HStack(spacing: 6) {
            #if os(tvOS)
            TVZoomButtons(session: session)
            TVMapButton(session: session, remote: tvRemote)
            #endif
            goalsButton
            researchButton
            standingsButton
            statisticsButton
            routesButton
            #if !os(tvOS)
            minimapButton
            #endif
            if settingsContent != nil {
                settingsButton
            }
        }
    }

    /// Shows and hides the corner minimap; M on the Mac. Spec:
    /// `platform-shells` / Minimap toggle.
    var minimapButton: some View {
        Button {
            showsMinimap.toggle()
        } label: {
            Image(systemName: showsMinimap ? "map.fill" : "map")
                .hudIconFont()
                .padding(8)
                .background(.thinMaterial, in: Circle())
        }
        .buttonStyle(.plain)
        .hotkey(KeyEquivalent(MinimapLayout.hotkey))
        .accessibilityLabel(showsMinimap ? "Hide Minimap" : "Show Minimap")
        .accessibilityIdentifier("hud.minimapToggle")
    }

    /// The same buttons folded into one More menu, for a phone in
    /// portrait. Spec: `platform-shells` / Adaptive HUD per idiom.
    var moreMenu: some View {
        Menu {
            if !session.world.goals.isEmpty {
                Button("Goals", systemImage: "flag.checkered") { goalsPresented = true }
            }
            Button("Research", systemImage: "book.fill") { researchPresented = true }
                .disabled(!session.isResearchAvailable)
            if StandingsPanelModel.isAvailable(in: session.world) {
                Button("Standings", systemImage: "trophy.fill") { standingsPresented = true }
            }
            Button("Statistics", systemImage: "chart.xyaxis.line") { session.isStatisticsPresented = true }
            if session.showsRoutesButton {
                Button("Routes", systemImage: "ferry.fill") { routesPresented = true }
            }
            #if !os(tvOS)
            Button(showsMinimap ? "Hide Minimap" : "Show Minimap", systemImage: "map") { showsMinimap.toggle() }
            #endif
            if settingsContent != nil {
                Button("Settings", systemImage: "gearshape.fill") { settingsPresented = true }
            }
        } label: {
            Image(systemName: "ellipsis.circle")
                .hudIconFont()
                .padding(8)
                .background(.thinMaterial, in: Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("More")
    }

    var researchButton: some View {
        Button {
            researchPresented = true
        } label: {
            Image(systemName: "book.fill")
                .hudIconFont()
                .padding(8)
                .background(.thinMaterial, in: Circle())
        }
        .buttonStyle(.plain)
        .disabled(!session.isResearchAvailable)
        .opacity(session.isResearchAvailable ? 1 : 0.4)
        .accessibilityLabel("Research")
    }

    var settingsButton: some View {
        Button {
            settingsPresented = true
        } label: {
            Image(systemName: "gearshape.fill")
                .hudIconFont()
                .padding(8)
                .background(.thinMaterial, in: Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Settings")
    }

    @ViewBuilder
    func pauseMenuContent() -> some View {
        if let viewModel = ensurePauseMenuViewModel() {
            PauseMenuView(viewModel: viewModel)
        }
    }

    func dismissPause() {
        session.isPaused = false
    }

    func settingsBinding(whilePaused: Bool) -> Binding<Bool> {
        Binding(
            get: {
                Self.presentsSettings(
                    fromPauseSheet: whilePaused, settingsPresented: settingsPresented, isPaused: session.isPaused
                )
            },
            set: { settingsPresented = $0 }
        )
    }

    /// Settings opens from the root, or from the pause sheet while the
    /// game is paused, because a view presents one sheet at a time.
    /// Closing it from the pause sheet leaves the pause menu open.
    nonisolated static func presentsSettings(fromPauseSheet: Bool, settingsPresented: Bool, isPaused: Bool) -> Bool {
        settingsPresented && isPaused == fromPauseSheet
    }

    /// Shows the in-game Settings sheet. The Mac app passes none: its
    /// Settings live in the standard Settings scene, which opens instead.
    func showSettings() {
        switch Self.settingsDestination(hasInGameSettings: settingsContent != nil) {
        case .sheet:
            settingsPresented = true
        case .settingsScene:
            #if os(macOS)
            openSettingsScene()
            #endif
        }
    }

    enum SettingsDestination: Equatable {
        case sheet, settingsScene
    }

    nonisolated static func settingsDestination(hasInGameSettings: Bool) -> SettingsDestination {
        hasInGameSettings ? .sheet : .settingsScene
    }

    /// Lazily build the pause menu view-model from the configuration
    /// supplied at init time. Cached so transient view-rebuilds reuse
    /// the same status-message state.
    @MainActor
    func ensurePauseMenuViewModel() -> PauseMenuViewModel? {
        if let existing = pauseMenuViewModel { return existing }
        guard let config = pauseMenuConfig else { return nil }
        let viewModel = PauseMenuViewModel(
            session: session,
            platform: config.platform,
            onSaveGame: config.onSaveGame,
            onSettings: { showSettings() },
            onQuitToTitle: config.onQuitToTitle,
            onQuit: config.onQuit
        )
        pauseMenuViewModel = viewModel
        return viewModel
    }
}
