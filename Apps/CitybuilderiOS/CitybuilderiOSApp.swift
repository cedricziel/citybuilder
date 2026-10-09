import CityAudio
import CityCore
import CityPersistence
import CityRender2D
import CityUI
import SwiftUI

@main
struct CitybuilderiOSApp: App {
    private let audio: AudioStack
    private let saveStore = SaveStore()
    /// Stable slot used by Continue + pause-menu Save. The title-screen
    /// flow reads this UUID when the player taps Continue; the in-game
    /// Save Game button writes to it. Spec
    /// `add-title-screen-and-new-game` design D6.
    private static let defaultGameID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!

    init() {
        let audio = AudioStack(cloudStore: UbiquitousAudioSettingsStore())
        self.audio = audio
        SnapshotRendererRegistry.shared
            .factory = { [audio] provider, tapSink, dragSink, hoverSink, longPressSink, ghostProvider, selectionProvider, routeProvider in
                AnyView(
                    IsoWorldView(
                        snapshotProvider: provider,
                        intentSink: { intent in
                            switch intent {
                            case let .tapTile(coord): tapSink(coord)
                            case let .dragTile(coord): dragSink(coord)
                            case let .hoverTile(coord): hoverSink(coord)
                            case let .longPressTile(coord): longPressSink(coord)
                            // The scene never emits these; the placement HUD drives
                            // the session directly.
                            case .panCamera, .pinchZoom, .confirmPlacement, .cancelPlacement, .nudgePlacement: break
                            }
                        },
                        ghostProvider: {
                            guard let state = ghostProvider() else { return nil }
                            return IsoWorldScene.GhostState(kind: state.kind, tile: state.tile, valid: state.valid)
                        },
                        selectionProvider: selectionProvider,
                        routeOverlayProvider: {
                            routeProvider().map {
                                IsoWorldScene.RouteOverlay(waypoints: $0.waypoints, redSegments: $0.redSegments, flash: $0.flash)
                            }
                        },
                        cameraListener: { tile in audio.setListenerPosition(tile) }
                    )
                )
            }
    }

    var body: some Scene {
        WindowGroup {
            TitleScreenHost(
                saveStore: SaveStoreFacadeAdapter(
                    store: saveStore,
                    defaultGameID: Self.defaultGameID
                ),
                sessionFactory: { [audio] world in
                    GameSession(
                        world: world,
                        audioEventConsumer: { events in
                            audio.consume(events: events)
                        },
                        audioSnapshotConsumer: { snapshot in
                            audio.consumeSnapshot(snapshot)
                        }
                    )
                },
                pauseMenuFactory: { [saveStore] session in
                    // onQuitToTitle is injected by TitleScreenHost — spec
                    // `wire-quit-to-title` D2 (centralized in the host).
                    PauseMenuConfig(
                        platform: .iOS,
                        onSaveGame: { [saveStore, session] in
                            try saveStore.save(session.world, gameID: Self.defaultGameID)
                        }
                    )
                },
                inGameSettings: { AudioSettingsSheet(audio: audio) },
                titleSettings: { AudioSettingsSheet(audio: audio) }
            )
        }
    }
}

/// Bridges `CityPersistence.SaveStore` into CityUI's `SaveStoreFacade`
/// without leaking the persistence type into CityUI. v0 surfaces one
/// fixed slot (`defaultGameID`); a future change can widen this to all
/// saves.
private struct SaveStoreFacadeAdapter: SaveStoreFacade {
    let store: SaveStore
    let defaultGameID: UUID

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

/// Tab container hosting `AudioSettingsView` + `CreditsView`. Pushed onto
/// the iOS HUD's settings sheet — same surface from the title screen too.
private struct AudioSettingsSheet: View {
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
            .navigationBarTitleDisplayMode(.inline)
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
