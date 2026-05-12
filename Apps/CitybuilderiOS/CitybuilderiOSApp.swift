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
        let audio = AudioStack()
        self.audio = audio
        _session = State(initialValue: GameSession(audioEventConsumer: { events in
            audio.consume(events: events)
        }))
    }

    var body: some Scene {
        WindowGroup {
            CityRootView(session: session)
        }
    }
}
