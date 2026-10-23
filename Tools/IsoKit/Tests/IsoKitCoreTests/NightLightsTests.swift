import SceneKit
import Testing
@testable import IsoKitCore

struct NightLightsTests {
    /// Two storeys of four windows on the south face.
    private let house = Recipe(id: "building-test-house", cell: SpriteCell(footprint: 2, heightPx: 128), constructionFrames: 0) { kit, _ in
        kit.block(SCNVector3(1, 0, 1), SCNVector3(7, 6, 7), .plaster)
        for storey in 0 ..< 2 {
            for along in [2.0, 3.4, 4.8, 6.2] {
                kit.window(Face.south(wallZ: 7), along: along, y: 1.5 + CGFloat(storey) * 3, lit: false)
            }
        }
    }

    private func glowing(_ scene: SCNNode) -> [SCNNode] {
        var nodes: [SCNNode] = []
        scene.enumerateHierarchy { node, _ in
            if node.geometry?.materials.contains(where: { $0.lightingModel == .constant }) == true { nodes.append(node) }
        }
        return nodes
    }

    @Test("scenario: Night lights glow from a few of the panes")
    func aFewPanesGlow() throws {
        let lights = try #require(house.lightsScene(variant: 0))
        // 30% of eight panes, rounded: two lamps, the rest dark.
        #expect(glowing(lights).count == 2)
        lights.enumerateHierarchy { node, _ in
            guard let materials = node.geometry?.materials else { return }
            let glows = materials.contains { $0.lightingModel == .constant }
            // Everything else writes depth only and draws first, or a pane drawn earlier would show through it.
            #expect(node.renderingOrder == (glows ? 1 : -1))
            let depthOnly = materials.allSatisfy(\.colorBufferWriteMask.isEmpty)
            #expect(glows || depthOnly)
        }
        let shed = Recipe(id: "building-test-shed", cell: SpriteCell(footprint: 1, heightPx: 64)) { kit, _ in
            kit.block(SCNVector3(1, 0, 1), SCNVector3(3, 2, 3), .planks)
        }
        #expect(shed.lightsScene(variant: 0) == nil)
        #expect(Recipes.lit.contains("building-house") && Recipes.lit.contains("building-bakery"))
        #expect(!Recipes.lit.contains("building-warehouse"))
    }

    @Test("each variant is stable, and the variants light different panes")
    func variantsAreStableAndDiffer() throws {
        func litHeights(_ variant: Int) throws -> [CGFloat] {
            try glowing(#require(house.lightsScene(variant: variant))).map { $0.worldPosition.x * 10 + $0.worldPosition.y }.sorted()
        }
        let first = try litHeights(1), again = try litHeights(1)
        #expect(first == again)
        let variants = try (0 ..< NightLights.variants).map(litHeights)
        #expect(Set(variants).count > 1)
    }

    @Test("about 30% of the panes are lit, at least one and at most three on a small house")
    func litCountIsAFew() {
        #expect(NightLights.litCount(panes: 1) == 1)
        #expect(NightLights.litCount(panes: 2) == 1)
        #expect(NightLights.litCount(panes: 8) == 2)
        #expect(NightLights.litCount(panes: 12) == 3)
        #expect(NightLights.litCount(panes: 20) == 6)
    }

    @Test("ground-floor panes are lit far more often than top-floor ones")
    func groundFloorIsFavoured() {
        let heights: [CGFloat] = [1, 1, 1, 4, 4, 4, 7, 7, 7]
        var ground = 0, top = 0
        for seed in 0 ..< 400 {
            for index in NightLights.pick(heights: heights, seed: NightLights.seed("house#\(seed)")) {
                if heights[index] == 1 { ground += 1 }
                if heights[index] == 7 { top += 1 }
            }
        }
        #expect(ground > top * 3)
        #expect(top > 0)
    }
}
