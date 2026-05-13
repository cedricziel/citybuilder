import AppKit
import CityAudio
import CityCore
import CityRender2D
import CityUI
import SwiftUI

@main
struct CitybuilderMacApp: App {
    @State private var session: GameSession
    private let audio: AudioStack
    /// Pinned to the app shell so its NotificationCenter observers
    /// stay alive for the app's lifetime. Spec:
    /// `add-fullscreen-launch` / `platform-shells` — Mac launches
    /// fullscreen by default + remembers user-driven transitions.
    private let fullscreenTracker: MacFullscreenTracker

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
        self.fullscreenTracker = MacFullscreenTracker()
    }

    var body: some Scene {
        WindowGroup {
            CityRootView(session: session)
                .frame(minWidth: 900, minHeight: 600)
                .onAppear {
                    fullscreenTracker.applyLaunchFullscreenIfNeeded()
                }
        }
        Settings {
            TabView {
                AudioSettingsView(settings: audio.settings)
                    .onDisappear {
                        Task { await audio.syncSettingsToCloud() }
                    }
                    .tabItem { Label("Audio", systemImage: "speaker.wave.2") }
                CreditsView(manifest: audio.manifest)
                    .tabItem { Label("Credits", systemImage: "info.circle") }
            }
            .frame(width: 480, height: 360)
        }
    }
}
