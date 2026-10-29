import CityAudio
import CityCore
import CityPersistence
import CityRender2D
import CityUI
import SwiftUI

@main
struct CitybuilderTVApp: App {
    private let audio: AudioStack
    private let saveStore: SaveStore
    private let saveSync: TVSaveSync
    private let campaignProgress = CampaignProgressStore.make()
    @Environment(\.scenePhase) private var scenePhase
    private static let defaultGameID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!

    init() {
        let saveStore = SaveStore(baseDirectory: Self.uiTestSaveDirectory)
        self.saveStore = saveStore
        saveSync = Self.makeSaveSync(store: saveStore)
        let audio = AudioStack(cloudStore: UbiquitousAudioSettingsStore())
        self.audio = audio
        UISounds.sink = { [audio] sound in audio.playInterfaceSound(sound.rawValue) }
        SnapshotRendererRegistry.shared
            .factory = { [audio] provider, tapSink, _, hoverSink, longPressSink, ghost, selection, inspecting, area, route in
                AnyView(
                    IsoWorldView(
                        snapshotProvider: provider,
                        intentSink: { intent in
                            switch intent {
                            case let .tapTile(coord): tapSink(coord)
                            case let .hoverTile(coord): hoverSink(coord)
                            case let .longPressTile(coord): longPressSink(coord)
                            case .dragTile, .panCamera, .pinchZoom, .confirmPlacement, .cancelPlacement, .nudgePlacement: break
                            }
                        },
                        ghostProvider: {
                            guard let state = ghost() else { return nil }
                            return IsoWorldScene.GhostState(kind: state.kind, tile: state.tile, valid: state.valid)
                        },
                        selectionProvider: selection,
                        inspectingProvider: inspecting,
                        areaOfEffectProvider: area,
                        routeOverlayProvider: {
                            route().map {
                                IsoWorldScene.RouteOverlay(waypoints: $0.waypoints, redSegments: $0.redSegments, flash: $0.flash)
                            }
                        },
                        cameraListener: { tile in audio.setListenerPosition(tile) },
                        showsStats: UITestSeed.showsStats(fromArguments: ProcessInfo.processInfo.arguments)
                    )
                )
            }
    }

    /// Debug launches with any `-uiTest…` flag (the walk-through UI tests pass `-uiTestResetSaves`)
    /// get an empty save folder of their own, an empty pending-upload list and a signed-out,
    /// in-memory iCloud: saves from iCloud or from manual runs cannot move the title's focus to
    /// Continue, and nothing the test plays reaches the player's saves.
    /// Debug launches with a `-uiTest…` flag save into a folder of their own (`UITestSeed.saveDirectory`).
    private static var uiTestSaveDirectory: URL? {
        #if DEBUG
        UITestSeed.saveDirectory(fromArguments: ProcessInfo.processInfo.arguments)
        #else
        nil
        #endif
    }

    private static func makeSaveSync(store: SaveStore) -> TVSaveSync {
        #if DEBUG
        if UITestSeed.isActive(fromArguments: ProcessInfo.processInfo.arguments) {
            let suite = "citybuilder.uiTests"
            try? FileManager.default.removeItem(at: store.baseDirectory)
            UserDefaults().removePersistentDomain(forName: suite)
            return TVSaveSync(
                store: store, client: InMemoryCloudKitClient(accountAvailable: false),
                deviceID: "Apple TV", defaultsSuite: suite
            )
        }
        #endif
        return TVSaveSync(store: store, client: CloudKitDatabaseClient(), deviceID: "Apple TV")
    }

    /// Debug builds start a new game from a `UITestSeed` world when launched with its flag
    /// (`-uiTestSeedTown`, `-uiTestSeedShore`, `-uiTestSeedPort`), for UI tests and art reviews.
    private static func uiTestWorld(replacing world: World) -> World {
        #if DEBUG
        return UITestSeed.world(fromArguments: ProcessInfo.processInfo.arguments) ?? world
        #else
        return world
        #endif
    }

    var body: some Scene {
        WindowGroup {
            TitleScreenHost(
                saveStore: SaveStoreFacadeAdapter(store: saveStore),
                sessionFactory: { [audio] world in
                    let session = GameSession(
                        world: Self.uiTestWorld(replacing: world),
                        audioEventConsumer: { events in
                            audio.consume(events: events)
                        },
                        audioSnapshotConsumer: { snapshot in
                            audio.consumeSnapshot(snapshot)
                        }
                    )
                    #if DEBUG
                    if UITestSeed.hidesFirstSteps(fromArguments: ProcessInfo.processInfo.arguments) {
                        session.hideFirstSteps()
                    }
                    #endif
                    // Leaving the game silences its workshop loops.
                    session.onEnd = { audio.endSession() }
                    audio.beginSession()
                    return session
                },
                pauseMenuFactory: { [saveStore, saveSync] session in
                    PauseMenuConfig(
                        platform: .tvOS,
                        onSaveGame: { [saveStore, saveSync, session] in
                            try saveStore.save(session.world, gameID: Self.defaultGameID)
                            Task { await saveSync.didSave(gameID: Self.defaultGameID) }
                        }
                    )
                },
                cloudSync: TitleScreenCloudSync(
                    restoreSaves: { [saveSync] in await saveSync.launch().conflicts },
                    isAccountAvailable: { [saveSync] in await saveSync.isAccountAvailable() },
                    resolveConflict: { [saveSync] gameID, keepICloud in
                        switch await saveSync.resolveConflict(gameID: gameID, keepICloud: keepICloud) {
                        case .resolved: .resolved
                        case .unreachable: .unreachable
                        case .superseded: .superseded
                        }
                    }
                ),
                campaignProgress: campaignProgress,
                inGameSettings: { SettingsSheet(audio: audio) },
                titleSettings: { SettingsSheet(audio: audio) }
            )
            .onChange(of: scenePhase) { _, phase in
                guard phase == .active else { return }
                Task { [saveSync] in await saveSync.retryPendingUploads() }
            }
        }
    }
}

private struct SaveStoreFacadeAdapter: SaveStoreFacade {
    let store: SaveStore

    func mostRecentSave() throws -> SaveSummary? {
        guard let meta = try store.mostRecentSave() else { return nil }
        return SaveSummary(
            gameID: meta.gameID,
            writeDate: meta.writeDate,
            displayName: meta.displayName
        )
    }

    func load(gameID: UUID) throws -> World {
        try store.load(gameID: gameID)
    }
}

private struct SettingsSheet: View {
    let audio: AudioStack
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            TabView {
                AudioSettingsView(
                    settings: audio.settings,
                    onSpatialEnabledChange: { [audio] enabled in
                        audio.engine.setSpatialEnabled(enabled)
                    },
                    onSpatialDistancesChange: { [audio] reference, maxDistance in
                        audio.engine.setSpatialDistances(reference: reference, max: maxDistance)
                    }
                )
                .tabItem { Label("Audio", systemImage: "speaker.wave.2") }
                CreditsView(manifest: audio.manifest)
                    .tabItem { Label("Credits", systemImage: "info.circle") }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        Task {
                            await audio.syncSettingsToCloud()
                        }
                        dismiss()
                    }
                }
            }
        }
    }
}
