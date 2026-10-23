import CityCore
import CoreGraphics
import SpriteKit

/// Now and then by day a fish jumps from the open water near the coast,
/// with a splash ring where it dives back in. At most one jump at a time:
/// a group, the fish and the ring. Drawn on scene time from a seeded
/// generator, never from the simulation. Spec: `rendering-2_5d` / Fish jump
/// near the coast.
final class FishLayerNode: SKNode {
    static let jumpName = "fish-jump"
    static let minZoom = 0.5
    static let gap: ClosedRange<Double> = 8 ... 15
    /// How far from land, in tiles, a fish may jump.
    static let reach = 4
    private var rng = DeterministicRNG(seed: 0xF15B_0A75)
    private(set) var nextJumpAt: TimeInterval?
    private var still = false

    var jump: SKNode? {
        childNode(withName: Self.jumpName)
    }

    /// Open water (water all round, so no shore tile) with land within
    /// `reach` tiles, in reading order.
    static func waters(in snapshot: WorldSnapshot, xRange: ClosedRange<Int>, yRange: ClosedRange<Int>) -> [TileCoordinate] {
        // Off the map counts as not water, so a tile at the edge is never open water.
        let isWater = { (x: Int, y: Int) in snapshot.terrain(at: TileCoordinate(x: x, y: y)) == .water }
        return yRange.flatMap { row in xRange.map { TileCoordinate(x: $0, y: row) } }.filter { tile in
            (-1 ... 1).allSatisfy { dy in (-1 ... 1).allSatisfy { dx in isWater(tile.x + dx, tile.y + dy) } }
                && (-reach ... reach).contains { dy in
                    (-reach ... reach).contains { dx in
                        abs(dx) + abs(dy) <= reach
                            && snapshot.terrain(at: TileCoordinate(x: tile.x + dx, y: tile.y + dy)).map { $0 != .water } ?? false
                    }
                }
        }
    }

    func reconcile(snapshot: WorldSnapshot, viewSize: CGSize, reduceMotion: Bool, still: Bool, now: TimeInterval) {
        let night = TimeOfDay(tick: snapshot.tickCount).phase == .night
        guard !reduceMotion, snapshot.camera.zoom >= Self.minZoom else {
            removeAllChildren()
            nextJumpAt = nil
            return
        }
        let hold = still || night
        if hold != self.still {
            self.still = hold
            jump?.speed = hold ? 0 : 1
        }
        guard !hold else { return }
        guard let due = nextJumpAt else {
            nextJumpAt = now + uniform(Self.gap)
            return
        }
        guard jump == nil, now >= due else { return }
        nextJumpAt = now + uniform(Self.gap)
        guard let range = Culling.visibleTileRange(
            camera: snapshot.camera, viewSize: viewSize, mapWidth: snapshot.mapWidth, mapHeight: snapshot.mapHeight
        )
        else { return }
        let waters = Self.waters(in: snapshot, xRange: range.xRange, yRange: range.yRange)
        guard !waters.isEmpty else { return }
        launch(at: IsoMath.screenPoint(forTile: waters[Int(rng.next() % UInt64(waters.count))]))
    }

    private func uniform(_ range: ClosedRange<Double>) -> Double {
        range.lowerBound + Double(rng.next() % 10000) / 10000 * (range.upperBound - range.lowerBound)
    }

    /// A short arc over the water, left or right, and a ring where it lands.
    private func launch(at start: CGPoint) {
        let side: CGFloat = rng.next().isMultiple(of: 2) ? 1 : -1
        let group = SKNode()
        group.name = Self.jumpName
        group.position = start
        group.zPosition = IsoWorldScene.figureZ(at: start)
        let fish = SKSpriteNode(texture: FishArt.frames[0], size: FishArt.size)
        fish.xScale = side
        let arc = CGMutablePath()
        arc.move(to: .zero)
        arc.addQuadCurve(to: CGPoint(x: side * 18, y: -2), control: CGPoint(x: side * 9, y: 26))
        fish.run(.sequence([
            .group([
                .follow(arc, asOffset: false, orientToPath: false, duration: 0.8),
                .animate(with: FishArt.frames, timePerFrame: 0.8 / 3)
            ]),
            .removeFromParent()
        ]))
        let ring = SKShapeNode(ellipseOf: CGSize(width: 10, height: 4))
        ring.strokeColor = SKColor(white: 1, alpha: 0.8)
        ring.lineWidth = 1
        // A small splash where it leaves the water, then the ring where it dives back in.
        ring.setScale(0.6)
        ring.run(.sequence([
            .group([.scale(to: 1.2, duration: 0.4), .fadeOut(withDuration: 0.4)]),
            .wait(forDuration: 0.35),
            .move(to: CGPoint(x: side * 18, y: -2), duration: 0),
            .scale(to: 0.6, duration: 0),
            .group([.fadeAlpha(to: 1, duration: 0.05), .scale(to: 2, duration: 0.7)]),
            .fadeOut(withDuration: 0.3)
        ]))
        group.addChild(fish)
        group.addChild(ring)
        addChild(group)
        group.run(.sequence([.wait(forDuration: 1.9), .removeFromParent()]))
    }
}

/// A small fish in three frames, rising, level and diving, drawn in code
/// at twice its size in points so it keeps its shape on a Retina screen:
/// a dark back, a pale belly, a forked tail and an eye.
@MainActor
enum FishArt {
    static let size = CGSize(width: 16, height: 8)
    static let frames: [SKTexture] = [CGFloat(0.45), 0, -0.45].map { frame(tilt: $0) }

    private static func frame(tilt: CGFloat) -> SKTexture {
        guard let context = CGContext(
            data: nil, width: 32, height: 16, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )
        else { return SKTexture() }
        context.translateBy(x: 17, y: 8)
        context.rotate(by: tilt)
        let body = CGPath(ellipseIn: CGRect(x: -9, y: -3.5, width: 17, height: 7), transform: nil)
        let tail = CGMutablePath()
        tail.addLines(between: [CGPoint(x: -8, y: 0), CGPoint(x: -14, y: 4.5), CGPoint(x: -12, y: 0), CGPoint(x: -14, y: -4.5)])
        tail.closeSubpath()
        context.setFillColor(CGColor(red: 0.33, green: 0.43, blue: 0.5, alpha: 1))
        context.addPath(tail)
        context.fillPath()
        context.setFillColor(CGColor(red: 0.88, green: 0.91, blue: 0.92, alpha: 1))
        context.addPath(body)
        context.fillPath()
        // The back: the body's upper half, darker.
        context.saveGState()
        context.addPath(body)
        context.clip()
        context.setFillColor(CGColor(red: 0.36, green: 0.47, blue: 0.55, alpha: 1))
        context.fill(CGRect(x: -10, y: 0.5, width: 20, height: 4))
        context.restoreGState()
        context.setStrokeColor(CGColor(red: 0.16, green: 0.22, blue: 0.27, alpha: 0.8))
        context.setLineWidth(1)
        context.addPath(body)
        context.strokePath()
        context.setFillColor(CGColor(red: 0.08, green: 0.1, blue: 0.12, alpha: 1))
        context.fillEllipse(in: CGRect(x: 4, y: 0, width: 1.6, height: 1.6))
        let texture = context.makeImage().map { SKTexture(cgImage: $0) } ?? SKTexture()
        texture.filteringMode = .linear
        return texture
    }
}

extension IsoWorldScene {
    /// Fish at the coast and sawdust at the sawmills.
    func reconcileWaterAndMills(with snapshot: WorldSnapshot, now: TimeInterval) {
        if fishLayer.parent == nil { addChild(fishLayer) }
        if sawdustLayer.parent == nil { addChild(sawdustLayer) }
        let paused = simulationIsStill(now: now)
        let night = TimeOfDay(tick: snapshot.tickCount).phase == .night
        fishLayer.reconcile(snapshot: snapshot, viewSize: size, reduceMotion: reduceMotion, still: paused, now: now)
        sawdustLayer.reconcile(snapshot: snapshot, viewSize: size, reduceMotion: reduceMotion, still: paused || night)
    }
}
