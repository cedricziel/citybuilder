import CityPersistence
import CityUI
import Foundation

/// Ties the current game's autosave to the app: attaches a coordinator to each
/// session, turns scene-phase changes into the leaving-the-foreground trigger
/// and stops it when the game ends. Spec: `persistence-save-load` / Autosave.
@MainActor
final class AutosaveHub {
    private let store: SaveStore
    private let gameID: UUID
    private let isEnabled: Bool
    private let didSave: @MainActor (UUID) -> Void
    private var coordinator: AutosaveCoordinator?

    /// `isEnabled` is false for UI-test and screenshot launches, whose seeded
    /// worlds must never reach a save slot. `didSave` runs after every
    /// autosave (Apple TV uploads it to iCloud).
    init(store: SaveStore, gameID: UUID, isEnabled: Bool = true, didSave: @escaping @MainActor (UUID) -> Void = { _ in }) {
        self.store = store
        self.gameID = gameID
        self.isEnabled = isEnabled
        self.didSave = didSave
    }

    /// Call once the session's own `onEnd` is set.
    func attach(to session: GameSession) {
        coordinator?.stop()
        coordinator = nil
        guard isEnabled else { return }
        let coordinator = AutosaveCoordinator(
            store: store,
            gameID: gameID,
            worldProvider: { [weak session] in session?.world },
            onResult: { [weak session, didSave, gameID] result in
                switch result {
                case let .saved(date):
                    session?.lastAutosave = date
                    didSave(gameID)
                case .failed:
                    session?.noteAutosaveFailed()
                }
            }
        )
        session.onPlayStep = { [weak coordinator] in coordinator?.playStepped() }
        session.onSeasonChange = { [weak coordinator] in coordinator?.request(.seasonChange) }
        let previousEnd = session.onEnd
        session.onEnd = { [weak coordinator] in
            previousEnd?()
            coordinator?.stop()
        }
        self.coordinator = coordinator
    }

    /// The app went to the background or is about to terminate.
    func appLeftForeground() {
        coordinator?.request(.leavingForeground)
    }

    /// The player chose to quit without saving: no write at termination.
    func stopForQuit() {
        coordinator?.stop()
    }

    static var isEnabledForLaunch: Bool {
        #if DEBUG
        !UITestSeed.isActive(fromArguments: ProcessInfo.processInfo.arguments)
        #else
        true
        #endif
    }
}
