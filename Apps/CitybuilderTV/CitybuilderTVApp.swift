import CityAudio
import CityCore
import CityPersistence
import CityRender2D
import CityUI
import SwiftUI

@main
struct CitybuilderTVApp: App {
    private let audio: AudioStack
    private let saveStore = SaveStore()
    private static let defaultGameID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!

    init() {
        let audio = AudioStack(cloudStore: UbiquitousAudioSettingsStore())
        self.audio = audio
        SnapshotRendererRegistry.shared
            .factory = { [audio] provider, tapSink, _, hoverSink, longPressSink, ghostProvider, selectionProvider, routeProvider in
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
                saveStore: SaveStoreFacadeAdapter(store: saveStore),
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
                    PauseMenuConfig(
                        platform: .iOS,
                        onSaveGame: { [saveStore, session] in
                            try saveStore.save(session.world, gameID: Self.defaultGameID)
                        }
                    )
                },
                inGameSettings: { SettingsSheet(audio: audio) },
                titleSettings: { SettingsSheet(audio: audio) }
            )
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
