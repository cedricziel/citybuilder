import CityCore
import SwiftUI

/// App-shell entry point. Hosts the title screen on launch and swaps in
/// `CityRootView` once the player commits a world. The host owns the
/// `TitleScreenViewModel` lifetime so its `committedSession` survives
/// SwiftUI view rebuilds. Spec: `add-title-screen-and-new-game` /
/// `title-screen` Requirement: App boot path.
public struct TitleScreenHost: View {
    @State private var viewModel: TitleScreenViewModel
    private let pauseMenuFactory: @MainActor (GameSession) -> PauseMenuConfig?
    private let inGameSettingsContent: (() -> AnyView)?
    private let titleSettingsContent: (() -> AnyView)?

    /// No settings surfaces. Useful when the platform reaches settings
    /// some other way (e.g. macOS's `Settings` scene via Cmd-,).
    public init(
        saveStore: SaveStoreFacade,
        sessionFactory: @escaping GameSessionFactory,
        pauseMenuFactory: @escaping @MainActor (GameSession) -> PauseMenuConfig? = { _ in nil }
    ) {
        _viewModel = State(
            initialValue: TitleScreenViewModel(saveStore: saveStore, sessionFactory: sessionFactory)
        )
        self.pauseMenuFactory = pauseMenuFactory
        self.inGameSettingsContent = nil
        self.titleSettingsContent = nil
    }

    /// Title-screen settings sheet only (no in-game gear). Mirrors
    /// macOS where in-game settings ride the standard `Settings` scene.
    public init(
        saveStore: SaveStoreFacade,
        sessionFactory: @escaping GameSessionFactory,
        pauseMenuFactory: @escaping @MainActor (GameSession) -> PauseMenuConfig? = { _ in nil },
        @ViewBuilder titleSettings: @escaping () -> some View
    ) {
        _viewModel = State(
            initialValue: TitleScreenViewModel(saveStore: saveStore, sessionFactory: sessionFactory)
        )
        self.pauseMenuFactory = pauseMenuFactory
        self.inGameSettingsContent = nil
        self.titleSettingsContent = { AnyView(titleSettings()) }
    }

    /// Both surfaces — the iOS path.
    public init(
        saveStore: SaveStoreFacade,
        sessionFactory: @escaping GameSessionFactory,
        pauseMenuFactory: @escaping @MainActor (GameSession) -> PauseMenuConfig? = { _ in nil },
        @ViewBuilder inGameSettings: @escaping () -> some View,
        @ViewBuilder titleSettings: @escaping () -> some View
    ) {
        _viewModel = State(
            initialValue: TitleScreenViewModel(saveStore: saveStore, sessionFactory: sessionFactory)
        )
        self.pauseMenuFactory = pauseMenuFactory
        self.inGameSettingsContent = { AnyView(inGameSettings()) }
        self.titleSettingsContent = { AnyView(titleSettings()) }
    }

    public var body: some View {
        if let session = viewModel.committedSession {
            gameView(session: session)
        } else {
            titleView
        }
    }

    @ViewBuilder
    private var titleView: some View {
        if let titleSettings = titleSettingsContent {
            TitleScreenView(viewModel: viewModel) {
                titleSettings()
            }
        } else {
            TitleScreenView(viewModel: viewModel)
        }
    }

    @ViewBuilder
    private func gameView(session: GameSession) -> some View {
        let wrappedConfig = pauseMenuFactory(session).map { config in
            Self.injectQuitToTitle(into: config, viewModel: viewModel)
        }
        if let inGameSettings = inGameSettingsContent {
            CityRootView(
                session: session,
                pauseMenu: wrappedConfig
            ) {
                inGameSettings()
            }
        } else {
            CityRootView(
                session: session,
                pauseMenu: wrappedConfig
            )
        }
    }

    /// Rebuild a `PauseMenuConfig` with `onQuitToTitle` bound to the
    /// view-model's `returnToTitle()`. Every other field is preserved.
    /// The pause-menu view-model runs `try? onSaveGame()` before this
    /// closure fires (spec `pause-menu` D7), so the title screen's
    /// `Continue` row picks up the just-written save when
    /// `returnToTitle()` refreshes `mostRecentSave`. Spec:
    /// `wire-quit-to-title` / `title-screen` Requirement: Host bridges
    /// pause-menu Quit to Title back to the title.
    @MainActor
    static func injectQuitToTitle(
        into config: PauseMenuConfig,
        viewModel: TitleScreenViewModel
    ) -> PauseMenuConfig {
        PauseMenuConfig(
            platform: config.platform,
            onSaveGame: config.onSaveGame,
            onQuitToTitle: { [weak viewModel] in
                viewModel?.returnToTitle()
            },
            onQuit: config.onQuit
        )
    }
}
