import CityCore
import CityRender2D
import CityUI
import SwiftUI

@main
struct CitybuilderiOSApp: App {
    init() {
        SnapshotRendererRegistry.shared.factory = { provider in
            AnyView(IsoWorldView(snapshotProvider: provider))
        }
    }

    var body: some Scene {
        WindowGroup {
            CityRootView()
        }
    }
}
