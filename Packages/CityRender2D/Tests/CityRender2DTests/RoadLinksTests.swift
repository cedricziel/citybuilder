import Testing
@testable import CityCore
@testable import CityRender2D

/// rendering-2_5d: Roads join their neighbours (replace-generative-sprites-with-isokit).
struct RoadLinksTests {
    private func tiles(_ points: [(Int, Int)]) -> Set<TileCoordinate> {
        Set(points.map { TileCoordinate(x: $0.0, y: $0.1) })
    }

    private func link(_ x: Int, _ y: Int, roads: Set<TileCoordinate>, townCenter: Set<TileCoordinate> = []) -> RoadLink? {
        RoadLinks.links(roads: roads, paved: roads.union(townCenter), townCenter: townCenter)[TileCoordinate(x: x, y: y)]
    }

    @Test("scenario: A straight road joins both neighbours")
    func straightRoad() {
        let road = tiles([(0, 0), (1, 0), (2, 0)])
        #expect(link(1, 0, roads: road) == RoadLink(mask: 1 | 4, plaza: false))
        #expect(link(0, 0, roads: road)?.assetName == "building-road-c1")
    }

    @Test("an L-turn has no corner fill unless the diagonal is paved")
    func turnWithoutDiagonal() {
        #expect(link(0, 0, roads: tiles([(0, 0), (1, 0), (0, 1)]))?.mask == 1 | 2)
        #expect(link(0, 0, roads: tiles([(0, 0), (1, 0), (0, 1), (1, 1)]))?.mask == 1 | 2 | 16)
    }

    @Test("scenario: A 2x2 block of road closes in the middle")
    func blockClosesInTheMiddle() {
        let block = tiles([(0, 0), (1, 0), (0, 1), (1, 1)])
        #expect(link(0, 0, roads: block)?.mask == 1 | 2 | 16)
        #expect(link(1, 0, roads: block)?.mask == 4 | 2 | 32)
        #expect(link(1, 1, roads: block)?.mask == 4 | 8 | 64)
        #expect(link(0, 1, roads: block)?.mask == 1 | 8 | 128)
    }

    @Test("scenario: The starter ring paves up to the town center")
    func ringPavesUpToTheTownCenter() {
        let center = tiles([(1, 1), (2, 1), (1, 2), (2, 2)])
        let ring = tiles([(0, 0), (1, 0), (2, 0), (3, 0)])
        #expect(link(1, 0, roads: ring, townCenter: center) == RoadLink(mask: 1 | 2 | 4 | 16, plaza: true))
        #expect(link(0, 0, roads: ring, townCenter: center)?.plaza == true) // touches the center diagonally
        #expect(link(0, 0, roads: tiles([(0, 0)]))?.assetName == "building-road-c0")
        #expect(link(1, 0, roads: ring, townCenter: center)?.assetName == "building-road-plaza-c23")
    }

    @Test("a new game's starter ring is drawn as plaza, joined into the town center")
    func newGameRingIsPlaza() {
        let snapshot = World.newGame().snapshot()
        let specs = SnapshotReconciler.desiredSprites(
            in: snapshot, xRange: 0 ... snapshot.mapWidth - 1, yRange: 0 ... snapshot.mapHeight - 1
        )
        let links = specs.compactMap { spec -> RoadLink? in
            guard case let .building(.road, .operational, _, _, _, _, _, _, _, link) = spec.kind else { return nil }
            return link
        }
        #expect(!links.isEmpty)
        let allPlaza = links.allSatisfy(\.plaza)
        #expect(allPlaza, "every starter road touches the town center")
        #expect(links.allSatisfy { RoadLinks.allMasks.contains($0.mask) })
    }

    @MainActor
    @Test("the factory draws a road's connection sprite, else its base sprite")
    func factoryDrawsTheConnectionSprite() {
        let scene = IsoWorldScene()
        let link = RoadLink(mask: 1 | 4, plaza: false)
        let spec = SpriteSpec(coord: TileCoordinate(x: 0, y: 0), kind: .building(
            kind: .road, state: .operational, footprint: BuildingCatalog.spec(for: .road).footprint, constructionFrameIndex: nil,
            orientation: nil, isWaitingForMaterials: false, roadLink: link
        ))
        scene.hasSprite = { $0 == link.assetName }
        #expect(scene.makeBuildingNode(for: spec).userData?[IsoWorldScene.textureNameKey] as? String == "building-road-c5")
        scene.hasSprite = { _ in false }
        #expect(scene.makeBuildingNode(for: spec).userData?[IsoWorldScene.textureNameKey] == nil)
    }
}
