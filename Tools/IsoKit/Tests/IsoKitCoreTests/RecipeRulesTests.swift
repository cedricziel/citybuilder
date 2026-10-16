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

    /// The game starts chimney smoke at this point, so it must follow the chimney the recipe builds.
    @Test("a recipe's chimney anchor is its chimney top, as fractions of the sprite")
    func chimneyAnchorIsTheChimneyTop() throws {
        let hut = Recipe(id: "building-test-hut", cell: SpriteCell(footprint: 2, heightPx: 128), constructionFrames: 0) { kit, _ in
            kit.chimney(x: 8, depth: 8, from: 0, to: 4)
        }
        let anchor = try #require(hut.chimneyAnchor)
        let top = Projection.screen(SCNVector3(8, 4, 8), in: hut.cell)
        #expect(abs(anchor.x - 0.5) < 0.001)
        #expect(abs(anchor.y - (1 - top.y / 128)) < 0.001)
        #expect(Recipe(id: "building-test-shed", cell: SpriteCell(footprint: 1, heightPx: 64)) { _, _ in }.chimneyAnchor == nil)
    }

    /// Inhabited houses smoke, so every house look needs a chimney for the smoke to rise from.
    @Test("every house tier and culture look has a chimney anchor")
    func everyHouseHasAChimneyAnchor() {
        let houses = Recipes.all.filter { $0.entry.hasPrefix("building-house") }
        #expect(houses.count >= 12)
        #expect(houses.filter { $0.chimneyAnchor == nil }.map(\.id).isEmpty)
    }

    /// With two chimneys the smoke rises from the one on the visible side.
    @Test("the chimney anchor is the chimney nearest the viewer")
    func chimneyAnchorPrefersTheVisibleChimney() throws {
        let hut = Recipe(id: "building-test-hut", cell: SpriteCell(footprint: 2, heightPx: 128), constructionFrames: 0) { kit, _ in
            kit.chimney(x: 2, depth: 2, from: 0, to: 6)
            kit.chimney(x: 6, depth: 6, from: 0, to: 4)
        }
        let expected = Projection.screen(SCNVector3(6, 4, 6), in: hut.cell)
        let anchor = try #require(hut.chimneyAnchor)
        // Both chimneys sit on the same screen column, so the height tells them apart.
        #expect(abs(anchor.x - expected.x / 128) < 0.001)
        #expect(abs(anchor.y - (1 - expected.y / 128)) < 0.001)
    }

    /// Night lights keep only the window panes; a building without one gets no lights at all.
    @Test("scenario: Night lights glow from the panes")
    func lightsKeepOnlyThePanes() throws {
        let hut = Recipe(id: "building-test-hut", cell: SpriteCell(footprint: 2, heightPx: 128), constructionFrames: 0) { kit, _ in
            kit.block(SCNVector3(1, 0, 1), SCNVector3(7, 3, 7), .plaster)
            kit.window(Face.south(wallZ: 7), along: 4, y: 1.5, lit: false)
        }
        let lights = try #require(hut.lightsScene())
        var glowing = 0, hidden = 0
        lights.enumerateHierarchy { node, _ in
            for material in node.geometry?.materials ?? [] {
                if material.lightingModel == .constant { glowing += 1 } else if material.colorBufferWriteMask.isEmpty { hidden += 1 }
            }
            // Occluders draw before panes, or a pane drawn first would show through them.
            if let materials = node.geometry?.materials {
                #expect(node.renderingOrder == (materials.contains { $0.lightingModel == .constant } ? 1 : -1))
            }
        }
        #expect(glowing == 1)
        #expect(hidden > 0)
        let shed = Recipe(id: "building-test-shed", cell: SpriteCell(footprint: 1, heightPx: 64)) { kit, _ in
            kit.block(SCNVector3(1, 0, 1), SCNVector3(3, 2, 3), .planks)
        }
        #expect(shed.lightsScene() == nil)
        #expect(Recipes.lit.contains("building-house") && Recipes.lit.contains("building-bakery"))
        #expect(!Recipes.lit.contains("building-warehouse"))
    }

    /// A unit has no plot overhang to crop, so any of it past the edge is clipped; the sail counts too.
    @Test("a unit whose moving part crosses the cell edge does not fit")
    func unitCellFitIsStrict() {
        let ship = Recipe(
            id: "ship-test", entry: "ship", cell: SpriteCell(footprint: 1, heightPx: 72),
            constructionFrames: 0, operationalFrames: 1,
            moving: MovingPart(name: "sail") { kit, _ in kit.block(SCNVector3(4.0, 0, 0), SCNVector3(4.1, 1, 0.1), .wood) },
            plot: nil, unit: true
        ) { kit, _ in kit.block(SCNVector3(1.5, 0, 1.5), SCNVector3(2.5, 1, 2.5), .wood) }
        #expect(!CellFit.problems(in: ship).isEmpty)
    }

    /// A bare band in a texture shows as a stripe wherever it repeats (the slate courses left one).
    /// Joints between blocks may be bare; a whole bare row may not.
    @Test("no finish texture has a bare row")
    func finishTexturesHaveNoBareRow() throws {
        let textures: [(String, CGImage)] = [
            ("plaster", Tex.plaster), ("timber", Tex.timber), ("rubble", Tex.rubble), ("ashlar", Tex.ashlar),
            ("planks", Tex.planks), ("thatch", Tex.thatchStraw), ("tile", Tex.tile), ("slate", Tex.slate),
            ("cobbles", Tex.cobbles), ("wood", Tex.wood), ("yard", Tex.yard), ("rock", Tex.rock), ("brick", Tex.brick)
        ]
        for (name, image) in textures {
            let size = Tex.size
            var pixels = [UInt8](repeating: 0, count: size * size * 4)
            let ctx = try #require(CGContext(
                data: &pixels, width: size, height: size, bitsPerComponent: 8, bytesPerRow: size * 4,
                space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ))
            ctx.draw(image, in: CGRect(x: 0, y: 0, width: size, height: size))
            let bareRows = (0 ..< size).filter { row in
                (0 ..< size).allSatisfy { pixels[(row * size + $0) * 4 + 3] == 0 }
            }
            #expect(bareRows.isEmpty, "\(name) has bare rows \(bareRows)")
        }
    }

    /// The renderer centres a W x H sprite on the footprint's width, level with its bottom vertex.
    @Test("a 2x3 cell is 160 points wide and centred on the footprint's width")
    func twoByThreeCellGeometry() {
        let cell = SpriteCell(footprint: 2, rows: 3, heightPx: 112)
        #expect(cell.widthPx == 160)
        let bottom = Projection.screen(SCNVector3(8, 0, 12), in: cell)
        #expect(abs(bottom.x - 64) < 0.001)
        #expect(abs(bottom.y) < 0.001)
        let left = Projection.screen(SCNVector3(0, 0, 12), in: cell)
        let right = Projection.screen(SCNVector3(8, 0, 0), in: cell)
        #expect(abs(left.x) < 0.001)
        #expect(abs(right.x - 160) < 0.001)
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
