import CityCore
import SwiftUI

/// Pause-menu view helpers split out of `CityRootView` so the main
/// file stays under SwiftLint's 500-line ceiling. Spec:
/// `add-game-pause-menu` / `pause-menu` (pause sheet + HUD button).
extension CityRootView {
    /// The menu buttons in one row at the top right: goals, research,
    /// standings and routes when they apply, then settings.
    var menuButtons: some View {
        HStack(spacing: 6) {
            goalsButton
            researchButton
            standingsButton
            routesButton
            if settingsContent != nil {
                settingsButton
            }
        }
    }

    var researchButton: some View {
        Button {
            researchPresented = true
        } label: {
            Image(systemName: "book.fill")
                .imageScale(.large)
                .padding(8)
                .background(.thinMaterial, in: Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Research")
    }

    var settingsButton: some View {
        Button {
            settingsPresented = true
        } label: {
            Image(systemName: "gearshape.fill")
                .imageScale(.large)
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
            onSettings: { settingsPresented = true },
            onQuitToTitle: config.onQuitToTitle,
            onQuit: config.onQuit
        )
        pauseMenuViewModel = viewModel
        return viewModel
    }
}
