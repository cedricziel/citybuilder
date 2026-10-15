import Foundation
import SceneKit
import Testing
@testable import IsoKitCore

/// Static rules every recipe must satisfy. None of these render, so they run in CI.
struct RecipeRulesTests {
    @Test("scenario: Recipes cannot add lights")
    func recipesCannotAddLights() {
        let lamp = MovingPart(name: "lamp") { kit, _ in
            let node = SCNNode()
            node.light = SCNLight()
            kit.root.addChildNode(node)
        }
        let recipe = Recipe(
            id: "building-test-lamp",
            cell: SpriteCell(footprint: 1, heightPx: 64),
            operationalFrames: 2,
            moving: lamp
        ) { kit, _ in
            kit.block(SCNVector3(0.5, 0, 0.5), SCNVector3(3.5, 2, 3.5), .plaster)
        }
        #expect(RecipeRules.problems(in: recipe) == [
            "building-test-lamp lamp frame 0: adds a light",
            "building-test-lamp lamp frame 1: adds a light"
        ])
    }

    @Test("scenario: Recipes use shared finishes")
    func recipesUseSharedFinishes() {
        let recipe = Recipe(
            id: "building-test-paint",
            cell: SpriteCell(footprint: 1, heightPx: 64),
            constructionFrames: 1,
            customStages: true
        ) { kit, stage in
            let box = kit.block(SCNVector3(0.5, 0, 0.5), SCNVector3(3.5, 2, 3.5), .plaster)
            if stage == .constructing(0) { box.geometry?.materials = [SCNMaterial()] }
        }
        #expect(RecipeRules.problems(in: recipe) == ["building-test-paint constructing-0: material unnamed is outside the finish set"])
    }

    @Test("every shipped recipe passes the rules at every stage and moving-part frame")
    func shippedRecipesPassTheRules() {
        #expect(Recipes.all.flatMap(RecipeRules.problems).isEmpty)
    }

    @Test("scenario: A recipe taller than its cell is rejected")
    func tallRecipeIsRejected() {
        let tower = Recipe(id: "building-test-tower", cell: SpriteCell(footprint: 2, heightPx: 112)) { kit, _ in
            kit.block(SCNVector3(2, 0, 2), SCNVector3(6, 30, 6), .ashlar)
        }
        let problems = CellFit.problems(in: tower)
        #expect(problems.contains { $0.contains("building-test-tower") && $0.contains("top") })
    }

    @Test("every shipped recipe fits its cell")
    func shippedRecipesFit() {
        for recipe in Recipes.all {
            #expect(CellFit.problems(in: recipe).isEmpty, "\(CellFit.problems(in: recipe))")
        }
    }

    @Test("a 2x2 cell is 128 points wide and its anchor sits at the bottom centre")
    func twoByTwoCellGeometry() {
        let cell = SpriteCell(footprint: 2, heightPx: 112)
        #expect(cell.widthPx == 128)
        let anchor = Projection.screen(SCNVector3(8, 0, 8), in: cell)
        #expect(abs(anchor.x - 64) < 0.001)
        #expect(abs(anchor.y) < 0.001)
        let topCorner = Projection.screen(SCNVector3(0, 0, 0), in: cell)
        #expect(abs(topCorner.y - 64) < 0.001)
    }

    @Test("scenario: Rendering needs no network")
    func renderingNeedsNoNetwork() throws {
        let sources = RepoPaths.root.appendingPathComponent("Tools/IsoKit/Sources")
        let banned = ["URLSession", "import Network", "NSURLConnection", "CFNetwork"]
        let files = FileManager.default.enumerator(at: sources, includingPropertiesForKeys: nil)?
            .compactMap { $0 as? URL }
            .filter { $0.pathExtension == "swift" } ?? []
        #expect(!files.isEmpty)
        for file in files {
            let text = try String(contentsOf: file, encoding: .utf8)
            for word in banned {
                #expect(!text.contains(word), "\(file.lastPathComponent) mentions \(word)")
            }
        }
    }
}

enum RepoPaths {
    /// Tools/IsoKit/Tests/IsoKitCoreTests/<file> -> repository root.
    static let root = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent()
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    static let catalog = root.appendingPathComponent("Resources/Sprites.style/catalog")
}
