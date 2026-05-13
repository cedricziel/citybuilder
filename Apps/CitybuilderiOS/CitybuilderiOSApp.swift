import CityAudio
import CityCore
import CityPersistence
import CityRender2D
import CityUI
import SwiftUI

@main
struct CitybuilderiOSApp: App {
    @State private var session: GameSession
    private let audio: AudioStack
    private let saveStore = SaveStore()
    /// Stable across launches until the title-screen change lands a
    /// real per-game UUID. Pause-menu Save / Quit-to-Title both write
    /// to this slot. Spec `add-game-pause-menu` design D6 + D7.
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
        _session = State(initialValue: GameSession(audioEventConsumer: { events in
            audio.consume(events: events)
        }))
    }

    var body: some Scene {
        WindowGroup {
            CityRootView(
                session: session,
                pauseMenu: PauseMenuConfig(
                    platform: .iOS,
                    onSaveGame: { [saveStore, session] in
                        try saveStore.save(session.world, gameID: Self.defaultGameID)
                    },
                    onQuitToTitle: nil,
                    onQuit: nil
                )
            ) {
                AudioSettingsSheet(audio: audio)
            }
        }
    }
}

/// Tab container hosting `AudioSettingsView` + `CreditsView`. Pushed onto
/// the iOS HUD's settings sheet. On Mac the same two views live in the
/// `Settings` scene instead.
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
                        // Mirror the latest values to iCloud on dismiss so
                        // cross-device sync stays prompt without observing
                        // every slider tick.
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
