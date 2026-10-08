import CityCore
import Foundation
import SpriteKit
import Testing
@testable import CityRender2D

// Tests for the waiting-for-materials badge added by
// `add-construction-stalls` → M8. Scenarios from
// openspec/changes/add-construction-stalls/specs/rendering-2_5d/spec.md
// under `Requirement: Waiting-for-materials badge`.

private let footprint = Footprint(width: 2, height: 2)

private func sawmillSpec(state: BuildingState, isWaiting: Bool) -> SpriteSpec {
    SpriteSpec(
        coord: TileCoordinate(x: 0, y: 0),
        kind: .building(
            kind: .sawmill,
            state: state,
            footprint: footprint,
            constructionFrameIndex: state == .constructing ? 0 : nil,
            orientation: nil,
            isWaitingForMaterials: isWaiting
        )
    )
}

@Test("scenario: waiting building shows the waiting badge")
@MainActor
func scenarioWaitingBuildingShowsTheWaitingBadge() {
    let scene = IsoWorldScene()
    let node = scene.makeBuildingNode(for: sawmillSpec(state: .constructing, isWaiting: true))
    let badge = node.childNode(withName: IsoWorldScene.waitingBadgeNodeName)
    #expect(badge != nil, "expected waiting overlay child")
}

@Test("scenario: actively constructing building shows no badge")
@MainActor
func scenarioActivelyConstructingBuildingShowsNoBadge() {
    let scene = IsoWorldScene()
    let node = scene.makeBuildingNode(for: sawmillSpec(state: .constructing, isWaiting: false))
    #expect(node.childNode(withName: IsoWorldScene.waitingBadgeNodeName) == nil)
}

@Test("scenario: operational building shows no badge")
@MainActor
func scenarioOperationalBuildingShowsNoBadge() {
    let scene = IsoWorldScene()
    let node = scene.makeBuildingNode(for: sawmillSpec(state: .operational, isWaiting: false))
    #expect(node.childNode(withName: IsoWorldScene.waitingBadgeNodeName) == nil)
}

@Test("scenario: disconnected building sprite carries the no-road marker")
@MainActor
func scenarioDisconnectedBuildingSpriteCarriesTheNoRoadMarker() {
    let scene = IsoWorldScene()
    let spec = SpriteSpec(
        coord: TileCoordinate(x: 0, y: 0),
        kind: .building(
            kind: .house, state: .operational, footprint: footprint,
            constructionFrameIndex: nil, orientation: nil,
            isWaitingForMaterials: false, isRoadDisconnected: true
        )
    )
    #expect(scene.makeBuildingNode(for: spec).childNode(withName: IsoWorldScene.noRoadBadgeNodeName) != nil)
    #expect(scene.makeBuildingNode(for: sawmillSpec(state: .operational, isWaiting: false))
        .childNode(withName: IsoWorldScene.noRoadBadgeNodeName) == nil)
}

@Test("scenario: a 2×3 building's sprite sits on its footprint")
@MainActor
func scenarioA2x3BuildingsSpriteSitsOnItsFootprint() {
    let spec = SpriteSpec(
        coord: TileCoordinate(x: 0, y: 0),
        kind: .building(
            kind: .port, state: .operational, footprint: Footprint(width: 2, height: 3),
            constructionFrameIndex: nil, orientation: .e, isWaitingForMaterials: false
        )
    )
    let node = IsoWorldScene().makeBuildingNode(for: spec)
    #expect(node.position == CGPoint(x: -16, y: -64))
}

@Test("scenario: square footprints keep their existing anchor")
@MainActor
func scenarioSquareFootprintsKeepTheirExistingAnchor() {
    let node = IsoWorldScene().makeBuildingNode(for: sawmillSpec(state: .operational, isWaiting: false))
    #expect(node.position == CGPoint(x: 0, y: -48))
}
