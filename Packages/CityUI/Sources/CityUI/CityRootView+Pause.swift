import CityCore
import SwiftUI

/// Pause-menu view helpers split out of `CityRootView` so the main
/// file stays under SwiftLint's 500-line ceiling. Spec:
/// `add-game-pause-menu` / `pause-menu` (pause sheet + HUD button).
extension CityRootView {
    /// Round HUD buttons in a 2×2 grid so the stats panel keeps its width
    /// on a phone: pause and settings on top, research and goals below.
    var hudButtons: some View {
        VStack(spacing: 6) {
            HStack(spacing: 6) {
                pauseButton
                if settingsContent != nil {
                    settingsButton
                }
            }
            HStack(spacing: 6) {
                researchButton
                goalsButton
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

    /// Pause button shown in the HUD top-right cluster. Glyph swaps
    /// with `session.isPaused`; ESC and Cmd-. mirror the tap.
    var pauseButton: some View {
        Button {
            session.isPaused.toggle()
        } label: {
            Image(systemName: pauseButtonSymbolName(isPaused: session.isPaused))
                .imageScale(.large)
                .padding(8)
                .background(.thinMaterial, in: Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(session.isPaused ? "Resume" : "Pause")
        .keyboardShortcut(.escape, modifiers: [])
        .keyboardShortcut(".", modifiers: .command)
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
