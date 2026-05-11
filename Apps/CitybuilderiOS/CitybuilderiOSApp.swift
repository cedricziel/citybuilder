import CityCore
import CityRender2D
import CityUI
import SwiftUI

@main
struct CitybuilderiOSApp: App {
    init() {
        SnapshotRendererRegistry.shared.factory = { provider, tapSink in
            AnyView(IsoWorldView(snapshotProvider: provider) { intent in
                if case let .tapTile(coord) = intent {
                    tapSink(coord)
                }
            })
        }
    }

    var body: some Scene {
        WindowGroup {
            CityRootView()
        }
    }
}
