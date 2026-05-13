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
        SnapshotRendererRegistry.shared.factory = { provider, tapSink, dragSink, hoverSink, ghostProvider in
            AnyView(
                IsoWorldView(
                    snapshotProvider: provider,
                    intentSink: { intent in
                        switch intent {
                        case let .tapTile(coord): tapSink(coord)
                        case let .dragTile(coord): dragSink(coord)
                        case let .hoverTile(coord): hoverSink(coord)
                        case .panCamera, .pinchZoom: break
                        }
                    },
                    ghostProvider: {
                        guard let state = ghostProvider() else { return nil }
                        return IsoWorldScene.GhostState(kind: state.kind, tile: state.tile, valid: state.valid)
                    }
                )
            )
        }
        let audio = AudioStack(cloudStore: UbiquitousAudioSettingsStore())
        self.audio = audio
    }

    var body: some Scene {
        WindowGroup {
            TitleScreenHost(
                saveStore: SaveStoreFacadeAdapter(
                    store: saveStore,
                    defaultGameID: Self.defaultGameID
                ),
                sessionFactory: { [audio] world in
                    GameSession(world: world, audioEventConsumer: { events in
                        audio.consume(events: events)
                    })
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
                AudioSettingsView(settings: audio.settings)
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
