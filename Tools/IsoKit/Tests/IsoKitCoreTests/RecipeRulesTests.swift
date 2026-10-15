import Foundation
import SceneKit
import Testing
@testable import IsoKitCore

/// Static rules every recipe must satisfy. None of these render, so they run in CI.
struct RecipeRulesTests {
    @Test("scenario: Recipes cannot add lights")
    func recipesCannotAddLights() {
        for recipe in Recipes.all {
            for stage in recipe.allStages {
                var lights: [String] = []
                recipe.build(stage: stage).enumerateHierarchy { node, _ in
                    if node.light != nil { lights.append(node.name ?? "?") }
                }
                #expect(lights.isEmpty, "\(recipe.id) stage \(stage) adds lights: \(lights)")
            }
        }
    }

    @Test("scenario: Recipes use shared finishes")
    func recipesUseSharedFinishes() {
        for recipe in Recipes.all {
            var foreign: [String] = []
            recipe.build(stage: .finished).enumerateHierarchy { node, _ in
                for material in node.geometry?.materials ?? [] where !Finish.isShared(material) {
                    foreign.append(material.name ?? "unnamed")
                }
            }
            #expect(foreign.isEmpty, "\(recipe.id) uses materials outside the finish set: \(foreign)")
        }
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
