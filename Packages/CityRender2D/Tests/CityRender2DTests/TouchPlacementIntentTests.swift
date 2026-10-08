import CityCore
import CoreGraphics
import Foundation
import Testing
@testable import CityRender2D

// Scenarios from openspec/changes/add-touch-first-placement/specs/rendering-2_5d.

@Test("scenario: IsoDirection NE moves ghost up-right by one tile")
func scenarioIsoDirectionNEMovesGhostUpRightByOneTile() {
    let offset = IsoDirection.ne.tileOffset
    #expect(offset.dx == 0)
    #expect(offset.dy == -1)
}

@Test("scenario: IsoDirection SE moves ghost down-right by one tile")
func scenarioIsoDirectionSEMovesGhostDownRightByOneTile() {
    let offset = IsoDirection.se.tileOffset
    #expect(offset.dx == 1)
    #expect(offset.dy == 0)
}

@Test("scenario: IsoDirection SW moves ghost down-left by one tile")
func scenarioIsoDirectionSWMovesGhostDownLeftByOneTile() {
    let offset = IsoDirection.sw.tileOffset
    #expect(offset.dx == 0)
    #expect(offset.dy == 1)
}

@Test("scenario: IsoDirection NW moves ghost up-left by one tile")
func scenarioIsoDirectionNWMovesGhostUpLeftByOneTile() {
    let offset = IsoDirection.nw.tileOffset
    #expect(offset.dx == -1)
    #expect(offset.dy == 0)
}

@Test("each iso direction moves its tile along the matching screen diagonal")
func isoDirectionOffsetsMatchTheRenderedDiagonals() {
    let origin = TileCoordinate(x: 5, y: 5)
    let originPoint = IsoMath.screenPoint(forTile: origin)
    for direction in [IsoDirection.ne, .se, .sw, .nw] {
        let offset = direction.tileOffset
        let moved = IsoMath.screenPoint(forTile: TileCoordinate(x: origin.x + offset.dx, y: origin.y + offset.dy))
        let right = moved.x > originPoint.x
        // Scene y is up-positive, so "up" on screen is a larger y.
        let up = moved.y > originPoint.y
        switch direction {
        case .ne: #expect(right && up)
        case .se: #expect(right && !up)
        case .sw: #expect(!right && !up)
        case .nw: #expect(!right && up)
        }
    }
}

@Test("scenario: long-press point translates to long-press intent at the tile under the touch")
func scenarioLongPressPointTranslatesToLongPressIntentAtTheTileUnderTheTouch() {
    let point = IsoMath.screenPoint(forTile: TileCoordinate(x: 5, y: 7))
    let intent = InputTranslator.longPressIntent(atScreenPoint: point, mapWidth: 32, mapHeight: 32)
    #expect(intent == .longPressTile(TileCoordinate(x: 5, y: 7)))
}

@Test("scenario: long-press outside map bounds dispatches no intent")
func scenarioLongPressOutsideMapBoundsDispatchesNoIntent() {
    let outside = IsoMath.screenPoint(forTile: TileCoordinate(x: 40, y: 3))
    #expect(InputTranslator.longPressIntent(atScreenPoint: outside, mapWidth: 32, mapHeight: 32) == nil)
    let negative = IsoMath.screenPoint(forTile: TileCoordinate(x: -1, y: 3))
    #expect(InputTranslator.longPressIntent(atScreenPoint: negative, mapWidth: 32, mapHeight: 32) == nil)
}

@Test("the placement intents compare by value")
func placementIntentsCompareByValue() {
    #expect(Intent.nudgePlacement(direction: .ne) == Intent.nudgePlacement(direction: .ne))
    #expect(Intent.nudgePlacement(direction: .ne) != Intent.nudgePlacement(direction: .sw))
    #expect(Intent.confirmPlacement != Intent.cancelPlacement)
}
