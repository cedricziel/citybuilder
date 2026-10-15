import CityCore
import Foundation
import SpriteKit

/// Turning pointer locations into tile intents: taps, long presses,
/// drags and hover. Kept out of `IsoWorldScene.swift` so that file stays
/// under SwiftLint's length limit.
extension IsoWorldScene {
    /// Finger / mouse moved while down: paint the tile under it.
    func handlePointerMoved(to sceneLocation: CGPoint) {
        dispatchDrag(at: sceneLocation)
    }

    /// Finger / mouse released. A release that ends a drag sends no
    /// tap: the drag already painted the last tile, and a tap there
    /// would be rejected as occupied.
    func handlePointerReleased(at sceneLocation: CGPoint) {
        if lastDragTile == nil {
            dispatchTap(at: sceneLocation)
        }
        lastDragTile = nil
    }

    private func tile(forScene location: CGPoint, mapWidth: Int, mapHeight: Int) -> TileCoordinate? {
        InputTranslator.tile(atScreenPoint: location, mapWidth: mapWidth, mapHeight: mapHeight)
    }

    private func dispatchTap(at sceneLocation: CGPoint) {
        guard let snapshot = dataSource?.currentSnapshot(),
              let coord = tile(forScene: sceneLocation, mapWidth: snapshot.mapWidth, mapHeight: snapshot.mapHeight)
        else { return }
        intentSink?(.tapTile(coord))
    }

    /// Long-press recognizer callback (`.began`): open the tile menu for
    /// the tile under the finger.
    func dispatchLongPress(at sceneLocation: CGPoint) {
        guard let snapshot = dataSource?.currentSnapshot(),
              let coord = tile(forScene: sceneLocation, mapWidth: snapshot.mapWidth, mapHeight: snapshot.mapHeight)
        else { return }
        intentSink?(.longPressTile(coord))
    }

    private func dispatchDrag(at sceneLocation: CGPoint) {
        guard let snapshot = dataSource?.currentSnapshot(),
              let coord = tile(forScene: sceneLocation, mapWidth: snapshot.mapWidth, mapHeight: snapshot.mapHeight)
        else { return }
        guard coord != lastDragTile else { return }
        for tile in Self.orthogonalSteps(from: lastDragTile, to: coord) {
            intentSink?(.dragTile(tile))
        }
        lastDragTile = coord
    }

    /// Tiles to paint when the finger moves from `from` to `to`: every
    /// tile on a 4-connected path, so a fast or diagonal drag never
    /// leaves a corner-only gap in a road. Steps along x first.
    static func orthogonalSteps(from: TileCoordinate?, to: TileCoordinate) -> [TileCoordinate] {
        guard var current = from else { return [to] }
        var steps: [TileCoordinate] = []
        while current != to {
            if current.x != to.x {
                current = TileCoordinate(x: current.x + (to.x > current.x ? 1 : -1), y: current.y)
            } else {
                current = TileCoordinate(x: current.x, y: current.y + (to.y > current.y ? 1 : -1))
            }
            steps.append(current)
        }
        return steps
    }

    func dispatchHover(at sceneLocation: CGPoint) {
        guard let snapshot = dataSource?.currentSnapshot() else { return }
        let coord = tile(forScene: sceneLocation, mapWidth: snapshot.mapWidth, mapHeight: snapshot.mapHeight)
        intentSink?(.hoverTile(coord))
    }
}
