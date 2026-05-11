import CityCore
import CityRender2D
import CityUI
import SwiftUI

@main
struct CitybuilderMacApp: App {
    init() {
        SnapshotRendererRegistry.shared.factory = { provider in
            AnyView(IsoWorldView(snapshotProvider: provider))
        }
    }

    var body: some Scene {
        WindowGroup {
            CityRootView()
                .frame(minWidth: 900, minHeight: 600)
        }
    }
}
