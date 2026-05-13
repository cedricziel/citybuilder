import CityCore
import Foundation

/// Lightweight summary of a save file, surfaced through the title-
/// screen `Continue` row. Mirrors `CityPersistence.SaveMetadata` but
/// lives in CityUI so the view-model stays free of any disk dependency.
/// The app shell adapts the persistence type into this one. Spec:
/// `add-title-screen-and-new-game` / `title-screen`.
public struct SaveSummary: Sendable, Equatable {
    public let gameID: UUID
    public let writeDate: Date
    public let displayName: String

    public init(gameID: UUID, writeDate: Date, displayName: String) {
        self.gameID = gameID
        self.writeDate = writeDate
        self.displayName = displayName
    }
}

/// Injection seam for the title-screen view-model: the app shell wires
/// a real `CityPersistence.SaveStore` adapter; tests use a fake.
public protocol SaveStoreFacade: Sendable {
    func mostRecentSave() throws -> SaveSummary?
    func load(gameID: UUID) throws -> World
}

/// Closure that builds a `GameSession` from a committed world. The
/// title screen calls this when the player picks New Game or Continue,
/// so `GameSession` construction is deferred until commit (no eager
/// 10 Hz timer against a soon-to-be-discarded world).
public typealias GameSessionFactory = @MainActor (World) -> GameSession

/// View-model behind `TitleScreenView`. Owns the visible state on the
/// title screen and routes the player's choice into a `GameSession` via
/// the injected factory. Spec: `add-title-screen-and-new-game` /
/// `title-screen` Requirement: Title screen view-model surface.
@MainActor
@Observable
public final class TitleScreenViewModel {
    public private(set) var mostRecentSave: SaveSummary?
    public var presentingNewGameDialog: Bool = false
    public var presentingSettings: Bool = false
    /// Set once the player has committed a world. Apps watch this to
    /// transition from the title screen to `CityRootView`.
    public private(set) var committedSession: GameSession?

    private let saveStore: SaveStoreFacade
    private let sessionFactory: GameSessionFactory

    public init(saveStore: SaveStoreFacade, sessionFactory: @escaping GameSessionFactory) {
        self.saveStore = saveStore
        self.sessionFactory = sessionFactory
        self.mostRecentSave = (try? saveStore.mostRecentSave()) ?? nil
    }

    /// Re-query the facade — useful after returning from the game to
    /// the title screen, so a freshly-written save shows up.
    public func refreshMostRecentSave() {
        mostRecentSave = (try? saveStore.mostRecentSave()) ?? nil
    }

    public func continueRequested() {
        guard let summary = mostRecentSave else { return }
        guard let world = try? saveStore.load(gameID: summary.gameID) else { return }
        commit(world: world)
    }

    public func newGameRequested() {
        presentingNewGameDialog = true
    }

    public func settingsRequested() {
        presentingSettings = true
    }

    public func commit(world: World) {
        let session = sessionFactory(world)
        presentingNewGameDialog = false
        committedSession = session
    }

    /// Tear down the active session reference and rebuild the title
    /// view. The pause-menu auto-save runs *before* this is invoked
    /// (per `add-game-pause-menu` Requirement: Quit to Title
    /// auto-saves), so refreshing `mostRecentSave` here surfaces that
    /// save in the `Continue` row immediately. Spec:
    /// `wire-quit-to-title` / `title-screen` Requirement: Return-to-
    /// title transition.
    public func returnToTitle() {
        committedSession = nil
        refreshMostRecentSave()
    }
}
