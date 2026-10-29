import CityCore
import Foundation
import os

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

/// A Continue load that failed. `reason` carries the underlying error
/// text for the log; the player sees `title`. Spec:
/// `surface-save-load-failure` / `persistence-save-load` Requirement:
/// Failed load is visible on the title screen.
public struct SaveLoadFailure: Sendable, Equatable {
    public static let title = "This save could not be loaded"

    public let gameID: UUID
    public let reason: String

    public init(gameID: UUID, reason: String) {
        self.gameID = gameID
        self.reason = reason
    }
}

/// Injection seam for the title-screen view-model: the app shell wires
/// a real `CityPersistence.SaveStore` adapter; tests use a fake.
public protocol SaveStoreFacade: Sendable {
    func mostRecentSave() throws -> SaveSummary?
    func load(gameID: UUID) throws -> World
}

/// How settling a save conflict ended. `superseded`: the iCloud copy
/// changed after the player was asked, so the player chooses again.
public enum SaveConflictResolution: Equatable, Sendable {
    case resolved
    case unreachable
    case superseded
}

/// iCloud hooks for a title screen whose saves need iCloud to survive,
/// as on Apple TV. `restoreSaves` downloads saves missing locally, runs
/// before the Continue row is read, and returns the games whose iCloud
/// copy is newer than the local one. `resolveConflict` keeps the iCloud
/// copy (true) or the local one (false), and says how that ended.
/// Spec: `icloud-sync`.
public struct TitleScreenCloudSync: Sendable {
    public let restoreSaves: @Sendable () async -> [UUID]
    public let isAccountAvailable: @Sendable () async -> Bool
    public let resolveConflict: @Sendable (UUID, Bool) async -> SaveConflictResolution

    public init(
        restoreSaves: @escaping @Sendable () async -> [UUID],
        isAccountAvailable: @escaping @Sendable () async -> Bool,
        resolveConflict: @escaping @Sendable (UUID, Bool) async -> SaveConflictResolution = { _, _ in .resolved }
    ) {
        self.restoreSaves = restoreSaves
        self.isAccountAvailable = isAccountAvailable
        self.resolveConflict = resolveConflict
    }
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
    /// Chapter select while it shows. Spec: `platform-shells` / Campaigns
    /// on the title screen.
    public private(set) var chapterSelect: ChapterSelectModel?
    /// The player's campaign progress, from the app shell's store.
    public let campaignProgress: CampaignProgressModel
    /// Saves a game before a card leaves it. A failed save keeps the game
    /// open, as the Mac's Quit does.
    public var saveGame: (@MainActor (GameSession) throws -> Void)?
    /// The culture the player last picked for a chapter that leaves it open.
    private var pickedCulture: Culture?
    /// Set once the player has committed a world. Apps watch this to
    /// transition from the title screen to `CityRootView`.
    public private(set) var committedSession: GameSession?
    public private(set) var loadFailure: SaveLoadFailure?
    /// Shown, and never dismissible, while no iCloud account is signed in
    /// on a title screen with cloud sync.
    public private(set) var iCloudNotice: String?
    /// Games whose iCloud save is newer than the local one, waiting for
    /// the player to pick which copy to keep.
    public private(set) var saveConflicts: [UUID] = []
    /// True while iCloud saves are being restored; Continue and New Game
    /// wait for it, so neither acts on a save the restore is replacing.
    public private(set) var isPreparingCloudSaves: Bool
    /// Why the last attempt to settle the first conflict failed.
    public private(set) var saveConflictFailure: String?
    /// True while a conflict is being settled.
    public private(set) var isResolvingSaveConflict = false

    public static let saveConflictSupersededText =
        "A newer save arrived in iCloud while you were choosing. Choose again."

    public static let saveConflictFailureText =
        "iCloud could not be reached. Check your connection and try again."

    public static let iCloudNoticeText =
        "Sign in to iCloud to keep your cities. Without it, Apple TV may delete your progress."

    private static let logger = Logger(subsystem: "com.cedricziel.citybuilder", category: "TitleScreen")

    private let saveStore: SaveStoreFacade
    private let sessionFactory: GameSessionFactory
    private let cloudSync: TitleScreenCloudSync?

    public init(
        saveStore: SaveStoreFacade,
        sessionFactory: @escaping GameSessionFactory,
        cloudSync: TitleScreenCloudSync? = nil,
        campaignProgress: CampaignProgressModel = CampaignProgressModel()
    ) {
        self.campaignProgress = campaignProgress
        self.saveStore = saveStore
        self.sessionFactory = sessionFactory
        self.cloudSync = cloudSync
        self.isPreparingCloudSaves = cloudSync != nil
        self.mostRecentSave = (try? saveStore.mostRecentSave()) ?? nil
    }

    /// Restores saves from iCloud, then re-reads the Continue row and the
    /// account notice. Does nothing without cloud sync.
    public func prepareCloudSaves() async {
        guard let cloudSync else { return }
        isPreparingCloudSaves = true
        saveConflicts = await cloudSync.restoreSaves()
        refreshMostRecentSave()
        isPreparingCloudSaves = false
        iCloudNotice = await cloudSync.isAccountAvailable() ? nil : Self.iCloudNoticeText
    }

    /// Settles the first pending conflict by keeping the iCloud copy or
    /// the local one, which then replaces the other. A conflict that could
    /// not be settled stays, with `saveConflictFailure` set.
    public func resolveSaveConflict(keepICloud: Bool) async {
        guard let cloudSync, let gameID = saveConflicts.first, !isResolvingSaveConflict else { return }
        isResolvingSaveConflict = true
        defer { isResolvingSaveConflict = false }
        let resolution = await cloudSync.resolveConflict(gameID, keepICloud)
        guard resolution == .resolved else {
            saveConflictFailure = resolution == .superseded ? Self.saveConflictSupersededText : Self.saveConflictFailureText
            return
        }
        saveConflictFailure = nil
        saveConflicts.removeAll { $0 == gameID }
        refreshMostRecentSave()
    }

    /// Re-query the facade — useful after returning from the game to
    /// the title screen, so a freshly-written save shows up.
    public func refreshMostRecentSave() {
        mostRecentSave = (try? saveStore.mostRecentSave()) ?? nil
    }

    public func continueRequested() {
        UISounds.play(.tap)
        guard !isPreparingCloudSaves, let summary = mostRecentSave else { return }
        let world: World
        do {
            world = try saveStore.load(gameID: summary.gameID)
        } catch {
            let failure = SaveLoadFailure(gameID: summary.gameID, reason: String(describing: error))
            Self.logger.error(
                "Continue failed to load save \(failure.gameID, privacy: .public): \(failure.reason, privacy: .public)"
            )
            loadFailure = failure
            return
        }
        commit(world: world)
    }

    public func dismissLoadFailure() {
        loadFailure = nil
    }

    public func newGameRequested() {
        UISounds.play(.tap)
        guard !isPreparingCloudSaves else { return }
        loadFailure = nil
        presentingNewGameDialog = true
    }

    public func campaignsRequested() {
        UISounds.play(.tap)
        guard !isPreparingCloudSaves else { return }
        loadFailure = nil
        chapterSelect = ChapterSelectModel(progress: campaignProgress)
    }

    public func dismissCampaigns() {
        chapterSelect = nil
    }

    /// Starts `chapter` on `world` and shows its intro card. `pickedCulture`
    /// is the player's pick, kept for later chapters that leave it open.
    public func startChapter(_ chapter: Chapter, world: World, pickedCulture: Culture? = nil) {
        if let pickedCulture { self.pickedCulture = pickedCulture }
        chapterSelect = nil
        commit(world: world, isNewGame: true)
        committedSession?.chapter = chapter
        committedSession?.showChapterIntro()
    }

    /// A card's action: the next chapter or a retry at the same difficulty
    /// and culture, or chapter select.
    func perform(_ action: ChapterAction, from session: GameSession) {
        switch action {
        case let .start(chapter):
            restart(chapter, like: session.world, culture: pickedCulture ?? session.world.culture)
        case .retry:
            if let chapter = session.currentChapter { restart(chapter, like: session.world, culture: session.world.culture) }
        case .backToChapters:
            do {
                try saveGame?(session)
            } catch {
                session.noteSaveFailure(error)
                return
            }
            returnToTitle()
            campaignsRequested()
        }
    }

    /// `culture` applies only when the chapter leaves the culture open.
    private func restart(_ chapter: Chapter, like world: World, culture: Culture) {
        let difficulty = chapter.difficulty(preferring: world.difficulty)
        startChapter(chapter, world: World.newGame(chapter: chapter, difficulty: difficulty, culture: culture))
    }

    public func settingsRequested() {
        UISounds.play(.tap)
        presentingSettings = true
    }

    /// With `-uiTestStartGame` (Debug only) the game starts without the title: the app's session
    /// factory swaps in the seed the other flags ask for.
    public func startGameIfRequested(arguments: [String]) {
        guard committedSession == nil, UITestSeed.startsGame(fromArguments: arguments) else { return }
        commit(world: World.newGame(layout: .singleIsland, seed: 0))
        if UITestSeed.opensStocks(fromArguments: arguments) {
            committedSession?.hud.toggleStocksTray()
        }
        if UITestSeed.opensOrders(fromArguments: arguments) {
            committedSession?.isOrdersPresented = true
        }
        if UITestSeed.opensStatistics(fromArguments: arguments) {
            committedSession?.isStatisticsPresented = true
            committedSession?.statisticsTab = UITestSeed.statisticsTab(fromArguments: arguments)
        }
        committedSession?.applyTestTool(fromArguments: arguments)
    }

    public func commit(world: World, isNewGame: Bool = false) {
        // End the old game before the factory starts the new one's sounds.
        committedSession?.end()
        let session = sessionFactory(world)
        session.offersPinchHint = isNewGame
        session.campaignProgress = campaignProgress
        session.onChapterAction = { [weak self, weak session] action in
            guard let self, let session else { return }
            perform(action, from: session)
        }
        // A chapter save from before its first tick still owes the intro.
        if world.chapterRules.chapterID != nil, world.tickCount == 0 {
            session.showChapterIntro()
        }
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
        committedSession?.end()
        committedSession = nil
        refreshMostRecentSave()
    }
}
