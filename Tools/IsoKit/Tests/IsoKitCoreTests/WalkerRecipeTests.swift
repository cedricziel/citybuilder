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

    @Test("walkers stand 5 pt above the cell's bottom edge and 12 pt from its left")
    func feetSitFivePointsUp() {
        let feet = Projection.screen(Recipes.walkerGround, in: Recipes.walkerCell)
        #expect(abs(feet.x - 12) < 0.001)
        #expect(abs(feet.y - 5) < 0.01)
    }

    @Test("the gait's two passing frames differ: each eases the other knee")
    func passingFramesDiffer() {
        func corners(_ phase: CGFloat) -> [String] {
            let kit = Builder()
            kit.figure(Recipes.storybook, phase: phase)
            return CellFit.corners(of: kit.root).map { String(format: "%.3f %.3f %.3f", $0.x, $0.y, $0.z) }.sorted()
        }
        #expect(corners(0) != corners(0.5))
    }

    @Test("frame 0 is a standing pose: both feet under the hips")
    func frameZeroStands() {
        let kit = Builder()
        kit.figure(Recipes.storybook, phase: 0)
        let bounds = CellFit.worldBounds(of: kit.root)
        // Walking, the stride spreads the feet 0.6 m along x; standing, the figure stays within its own depth.
        #expect(bounds.max.x - bounds.min.x < 0.5)
    }

    @Test("animals render walk, graze and peck cycles in four facings")
    func animalNames() {
        func names(_ stem: String, _ frames: Int) -> Set<String> {
            Set(WalkerFacing.allCases.flatMap { facing in (0 ..< frames).map { "\(stem)-\(facing.rawValue)-\($0)" } })
        }
        let animals = Recipes.all.filter { $0.entry == "animal" }
        let rendered = Set(animals.flatMap(\.spriteNames))
        let expected = names("animal-sheep-walk", 8).union(names("animal-sheep-graze", 4))
            .union(names("animal-cow-walk", 8)).union(names("animal-cow-graze", 4)).union(names("animal-hen", 4))
        #expect(rendered == expected)
    }

    /// The renderer anchors animals where the brief's `Anchor:` lines say; the pens must render the feet there.
    @Test("animal pens put the feet where the animal brief's Anchor lines say")
    func pensMatchTheBrief() throws {
        let brief = try String(contentsOf: RepoPaths.catalog.appendingPathComponent("animal.md"), encoding: .utf8)
        for (animal, pen) in [("sheep", Recipes.sheepPen), ("cow", Recipes.cowPen), ("hen", Recipes.henPen)] {
            let line = try #require(brief.split(separator: "\n").first { $0.hasPrefix("- Anchor \(animal):") })
            let numbers = line.split(whereSeparator: { !"0123456789".contains($0) }).compactMap { Double($0) }
            #expect(numbers == [Double(pen.feetX), Double(pen.feetY), Double(pen.width), Double(pen.height)], "\(line)")
            let feet = Projection.screen(pen.ground, in: pen.cell)
            #expect(abs(feet.x - pen.feetX) < 0.01 && abs(feet.y - pen.feetY) < 0.01)
        }
    }
}
