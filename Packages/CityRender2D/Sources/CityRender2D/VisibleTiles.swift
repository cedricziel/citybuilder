import CityCore
import CoreGraphics
import Foundation

/// The tiles whose centre lies in `Culling.screenBounds`, as one run of columns per row of the
/// culling range. Two views compare cheaply, so the scene redraws terrain only when the view changes,
/// and then only the tiles that entered or left it.
public struct VisibleTiles: Equatable, Sendable {
    /// The culling range: the screen's bounding box in tile space.
    public let xRange: ClosedRange<Int>
    public let yRange: ClosedRange<Int>
    /// The columns on screen in each row of `yRange`, nil where none are.
    let columns: [ClosedRange<Int>?]

    public init?(camera: Camera, viewSize: CGSize, mapWidth: Int, mapHeight: Int) {
        guard let (xRange, yRange) = Culling.visibleTileRange(
            camera: camera, viewSize: viewSize, mapWidth: mapWidth, mapHeight: mapHeight, margin: Culling.screenMargin
        )
        else { return nil }
        let bounds = Culling.screenBounds(camera: camera, viewSize: viewSize)
        self.xRange = xRange
        self.yRange = yRange
        columns = yRange.map { Self.columns(inRow: $0, of: xRange, on: bounds) }
    }

    public func contains(_ coord: TileCoordinate) -> Bool {
        run(inRow: coord.y)?.contains(coord.x) == true
    }

    /// Every tile in the view.
    public var tiles: [TileCoordinate] {
        tiles(notIn: nil)
    }

    /// The tiles in this view that `other` lacks: per row, this run minus the other's.
    public func tiles(notIn other: VisibleTiles?) -> [TileCoordinate] {
        var result: [TileCoordinate] = []
        for row in yRange {
            guard let mine = run(inRow: row) else { continue }
            var pieces = [mine.lowerBound ..< mine.upperBound + 1]
            if let theirs = other?.run(inRow: row), theirs.overlaps(mine) {
                pieces = [
                    mine.lowerBound ..< max(mine.lowerBound, theirs.lowerBound),
                    min(theirs.upperBound + 1, mine.upperBound + 1) ..< mine.upperBound + 1
                ]
            }
            for piece in pieces {
                result += piece.map { TileCoordinate(x: $0, y: row) }
            }
        }
        return result
    }

    private func run(inRow row: Int) -> ClosedRange<Int>? {
        yRange.contains(row) ? columns[row - yRange.lowerBound] : nil
    }

    /// Screen x rises and screen y falls with the column, so a row's columns on screen form one run.
    /// Its ends are solved from the bounds, then settled on the same `contains` test the full scan
    /// used, so rounding never moves a tile in or out.
    static func columns(inRow row: Int, of range: ClosedRange<Int>, on bounds: CGRect) -> ClosedRange<Int>? {
        let shows = { (column: Int) in bounds.contains(IsoMath.screenPoint(forTile: TileCoordinate(x: column, y: row))) }
        let halfWidth = IsoMath.tileWidth / 2
        let halfHeight = IsoMath.tileHeight / 2
        let rowValue = CGFloat(row)
        let first = max(rowValue + bounds.minX / halfWidth, -rowValue - bounds.maxY / halfHeight).rounded(.up)
        let last = min(rowValue + bounds.maxX / halfWidth, -rowValue - bounds.minY / halfHeight).rounded(.down)
        var low = Int(min(max(first, CGFloat(range.lowerBound)), CGFloat(range.upperBound) + 1))
        var high = Int(max(min(last, CGFloat(range.upperBound)), CGFloat(range.lowerBound) - 1))
        while low > range.lowerBound, shows(low - 1) {
            low -= 1
        }
        while high < range.upperBound, shows(high + 1) {
            high += 1
        }
        while low <= high, !shows(low) {
            low += 1
        }
        while high >= low, !shows(high) {
            high -= 1
        }
        return low <= high ? low ... high : nil
    }
}
