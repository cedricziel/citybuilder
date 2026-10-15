import Foundation
import SceneKit
import Testing
@testable import IsoKitCore

/// realistic-walkers: the people recipes, their names and their cell. None of these render.
struct WalkerRecipeTests {
    static func names(_ stems: [String]) -> Set<String> {
        Set(stems.flatMap { stem in
            WalkerFacing.allCases.flatMap { facing in (0 ..< Recipes.gaitFrames).map { "\(stem)-\(facing.rawValue)-\($0)" } }
        })
    }

    @Test("the walker brief holds residents and carriers: 4 facings x 8 gait frames each")
    func walkerNames() {
        let people = Recipes.all.filter { $0.entry == "walker" }
        let walkers = people.filter { $0.id.hasPrefix("walker-") }
        let carriers = people.filter { $0.id.hasPrefix("carrier-") }
        #expect(walkers.count + carriers.count == people.count)
        let allUnits = (walkers + carriers).allSatisfy(\.unit)
        let walkerNames = Set(walkers.flatMap(\.spriteNames))
        let carrierNames = Set(carriers.flatMap(\.spriteNames))
        #expect(allUnits)
        #expect(walkerNames == Self.names(["walker", "walker-woman"]))
        #expect(carrierNames == Self.names(["carrier-sack", "carrier-crate", "carrier-barrel", "carrier-logs"]))
    }

    @Test("walkers stand 2 pt above the cell's bottom edge, at its centre")
    func feetSitTwoPointsUp() {
        let feet = Projection.screen(Recipes.walkerGround, in: Recipes.walkerCell)
        #expect(abs(feet.x - 12) < 0.001)
        #expect(abs(feet.y - 2) < 0.01)
    }

    @Test("frame 0 is a standing pose: both feet under the hips")
    func frameZeroStands() {
        let kit = Builder()
        kit.figure(Recipes.storybook, phase: 0)
        let bounds = CellFit.worldBounds(of: kit.root)
        // Walking, the stride spreads the feet 0.7 m along x; standing, the figure stays within its own depth.
        #expect(bounds.max.x - bounds.min.x < 0.5)
    }
}
