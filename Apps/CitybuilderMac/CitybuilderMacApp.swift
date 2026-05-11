import CityCore
import CityRender2D
import CityUI
import SwiftUI

@main
struct CitybuilderMacApp: App {
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
                .frame(minWidth: 900, minHeight: 600)
        }
    }
}
