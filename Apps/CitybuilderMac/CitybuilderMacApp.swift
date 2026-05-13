import AppKit
import CityAudio
import CityCore
import CityPersistence
import CityRender2D
import CityUI
import SwiftUI

@main
struct CitybuilderMacApp: App {
    private let audio: AudioStack
    /// Pinned to the app shell so its NotificationCenter observers
    /// stay alive for the app's lifetime. Spec:
    /// `add-fullscreen-launch` / `platform-shells` — Mac launches
    /// fullscreen by default + remembers user-driven transitions.
    private let fullscreenTracker: MacFullscreenTracker
    private let saveStore = SaveStore()
    /// Stable slot used by Continue + pause-menu Save. Spec
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
        self.fullscreenTracker = MacFullscreenTracker()
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
                        platform: .mac,
                        onSaveGame: { [saveStore, session] in
                            try saveStore.save(session.world, gameID: Self.defaultGameID)
                        },
                        onQuit: { NSApplication.shared.terminate(nil) }
                    )
                },
                titleSettings: { TitleSettingsSheet(audio: audio) }
            )
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

/// Title-screen Settings sheet on macOS. Renders the same audio +
/// credits surface the `Settings` scene shows, so the player can reach
/// settings before committing to a world without an additional menu
/// step. Cmd-, still opens the standard Settings scene.
private struct TitleSettingsSheet: View {
    let audio: AudioStack
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            TabView {
                AudioSettingsView(settings: audio.settings)
                    .tabItem { Label("Audio", systemImage: "speaker.wave.2") }
                CreditsView(manifest: audio.manifest)
                    .tabItem { Label("Credits", systemImage: "info.circle") }
            }
            HStack {
                Spacer()
                Button("Done") {
                    Task { await audio.syncSettingsToCloud() }
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding()
        }
        .frame(width: 480, height: 360)
    }
}

/// Bridges `CityPersistence.SaveStore` into CityUI's `SaveStoreFacade`
/// without leaking the persistence type into CityUI.
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
