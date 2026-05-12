import CityAudio
import CityCore
import CityRender2D
import CityUI
import SwiftUI

@main
struct CitybuilderiOSApp: App {
    @State private var session: GameSession
    private let audio: AudioStack

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
            CityRootView(session: session) {
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
