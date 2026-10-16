import CityCore
import CoreGraphics
import SpriteKit

/// Flocks crossing the view and gulls over the coast. Drawn on scene time,
/// never from the simulation. Spec: `rendering-2_5d` / Birds cross the sky.
enum BirdPlanner {
    static let flockSizes = 5 ... 9
    /// Seconds between flocks.
    static let flockGap: ClosedRange<Double> = 40 ... 90
    static let gullCount = 3
    static let gullMinZoom = 0.5

    /// A loose V behind a leader at the origin, flying toward +x.
    static func flockOffsets(count: Int) -> [CGPoint] {
        (0 ..< count).map { index in
            guard index > 0 else { return .zero }
            let rank = CGFloat((index + 1) / 2), side: CGFloat = index.isMultiple(of: 2) ? 1 : -1
            return CGPoint(x: -rank * 14, y: side * rank * 9)
        }
    }

    /// A visible water tile with land beside it, nearest the camera
    /// centre (ties by reading order), or nil when no coast is in view.
    static func coastTile(
        in snapshot: WorldSnapshot, xRange: ClosedRange<Int>, yRange: ClosedRange<Int>
    ) -> TileCoordinate? {
        let centre = (x: snapshot.camera.centerX, y: snapshot.camera.centerY)
        var best: (tile: TileCoordinate, distance: Double)?
        for row in yRange {
            for col in xRange {
                let tile = TileCoordinate(x: col, y: row)
                guard snapshot.terrain(at: tile) == .water else { continue }
                let neighbours = [(1, 0), (-1, 0), (0, 1), (0, -1)].map { TileCoordinate(x: col + $0.0, y: row + $0.1) }
                guard neighbours.contains(where: { (snapshot.terrain(at: $0) ?? .water) != .water }) else { continue }
                let distance = (Double(col) - centre.x) * (Double(col) - centre.x) + (Double(row) - centre.y) * (Double(row) - centre.y)
                if best == nil || distance < best!.distance { best = (tile, distance) }
            }
        }
        return best?.tile
    }
}

/// Two-frame flapping silhouettes drawn in code: dark birds and white
/// gulls with dark wing tips.
@MainActor
enum BirdArt {
    static let bird = frames(body: CGColor(red: 0.12, green: 0.11, blue: 0.10, alpha: 1), tips: nil)
    static let gull = frames(
        body: CGColor(red: 0.97, green: 0.97, blue: 0.95, alpha: 1), tips: CGColor(red: 0.2, green: 0.2, blue: 0.22, alpha: 1)
    )

    private static func frames(body: CGColor, tips: CGColor?) -> [SKTexture] {
        // Wings up, then wings level; Core Graphics counts rows from the bottom.
        let strokes: [[CGPoint]] = [
            [CGPoint(x: 1, y: 7), CGPoint(x: 5, y: 3), CGPoint(x: 8, y: 4), CGPoint(x: 11, y: 3), CGPoint(x: 15, y: 7)],
            [CGPoint(x: 1, y: 3), CGPoint(x: 5, y: 4), CGPoint(x: 8, y: 3), CGPoint(x: 11, y: 4), CGPoint(x: 15, y: 3)]
        ]
        return strokes.map { points in
            guard let context = CGContext(
                data: nil, width: 16, height: 9, bitsPerComponent: 8, bytesPerRow: 0,
                space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            )
            else { return SKTexture() }
            context.setLineCap(.round)
            context.setLineJoin(.round)
            context.setLineWidth(1.8)
            context.setStrokeColor(body)
            context.addLines(between: points)
            context.strokePath()
            if let tips, let first = points.first, let last = points.last {
                context.setStrokeColor(tips)
                context.addLines(between: [first, points[1]])
                context.addLines(between: [points[3], last])
                context.setLineWidth(1)
                context.strokePath()
            }
            let texture = context.makeImage().map { SKTexture(cgImage: $0) } ?? SKTexture()
            texture.filteringMode = .linear
            return texture
        }
    }

    static func flap(_ node: SKSpriteNode, frames: [SKTexture], phase: Double) {
        node.run(.sequence([.wait(forDuration: phase), .repeatForever(.animate(with: frames, timePerFrame: 0.16))]))
    }
}

final class BirdLayerNode: SKNode {
    static let flockName = "flock"
    static let gullsName = "gulls"
    private var rng = DeterministicRNG(seed: 0xB1D5_F10C)
    private(set) var nextFlockAt: TimeInterval?
    private var gullTile: TileCoordinate?
    private var lastRange: String?

    override init() {
        super.init()
        zPosition = 90 // over the buildings, under the night shade (95)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    var flock: SKNode? {
        childNode(withName: Self.flockName)
    }

    var gulls: SKNode? {
        childNode(withName: Self.gullsName)
    }

    func reconcile(snapshot: WorldSnapshot, viewSize: CGSize, reduceMotion: Bool, now: TimeInterval) {
        guard StrollerPlanner.residentsOut(atTick: snapshot.tickCount), !reduceMotion else {
            removeAllChildren()
            nextFlockAt = nil
            gullTile = nil
            lastRange = nil
            return
        }
        let range = Culling.visibleTileRange(
            camera: snapshot.camera, viewSize: viewSize, mapWidth: snapshot.mapWidth, mapHeight: snapshot.mapHeight
        )
        updateGulls(snapshot: snapshot, range: range)
        guard let due = nextFlockAt else {
            nextFlockAt = now + uniform(10 ... 25)
            return
        }
        if flock == nil, now >= due {
            launchFlock(camera: snapshot.camera, viewSize: viewSize)
            nextFlockAt = now + uniform(BirdPlanner.flockGap)
        }
    }

    private func uniform(_ range: ClosedRange<Double>) -> Double {
        range.lowerBound + Double(rng.next() % 10000) / 10000 * (range.upperBound - range.lowerBound)
    }

    private func launchFlock(camera: Camera, viewSize: CGSize) {
        let centre = IsoMath.screenPoint(forTileFractionalX: camera.centerX, fractionalY: camera.centerY)
        let reach = (viewSize.width * viewSize.width + viewSize.height * viewSize.height).squareRoot() / (2 * CGFloat(camera.zoom)) + 80
        let angle = CGFloat(uniform(0 ... 2 * Double.pi))
        let direction = CGVector(dx: cos(angle), dy: sin(angle))
        let start = CGPoint(x: centre.x - direction.dx * reach, y: centre.y - direction.dy * reach)
        let end = CGPoint(x: centre.x + direction.dx * reach, y: centre.y + direction.dy * reach)
        let flock = SKNode()
        flock.name = Self.flockName
        flock.position = start
        let count = BirdPlanner.flockSizes.lowerBound + Int(rng.next() % UInt64(BirdPlanner.flockSizes.count))
        for (index, offset) in BirdPlanner.flockOffsets(count: count).enumerated() {
            // Rotate the V so it points along the flight.
            let place = CGPoint(
                x: offset.x * direction.dx - offset.y * direction.dy,
                y: offset.x * direction.dy + offset.y * direction.dx
            )
            let shadow = SKSpriteNode(texture: BirdArt.bird[1])
            shadow.color = .black
            shadow.colorBlendFactor = 1
            shadow.alpha = 0.16
            shadow.position = CGPoint(x: place.x + 30, y: place.y - 70)
            shadow.zPosition = -1
            flock.addChild(shadow)
            let bird = SKSpriteNode(texture: BirdArt.bird[0])
            bird.position = place
            BirdArt.flap(bird, frames: BirdArt.bird, phase: Double(index) * 0.05)
            flock.addChild(bird)
        }
        addChild(flock)
        let distance = 2 * reach, speed: CGFloat = 70
        flock.run(.sequence([.move(to: end, duration: TimeInterval(distance / speed)), .removeFromParent()]))
    }

    private func updateGulls(snapshot: WorldSnapshot, range: (xRange: ClosedRange<Int>, yRange: ClosedRange<Int>)?) {
        // The coast is looked for again when the view or the zoom gate
        // changes, and every 5 s for new shoreline.
        let near = snapshot.camera.zoom >= BirdPlanner.gullMinZoom
        let key = range.map { "\($0.xRange)\($0.yRange)\(near)\(snapshot.tickCount / 50)" }
        guard key != lastRange else { return }
        lastRange = key
        let tile = range.flatMap { near
            ? BirdPlanner.coastTile(in: snapshot, xRange: $0.xRange, yRange: $0.yRange)
            : nil
        }
        guard tile != gullTile || (tile != nil && gulls == nil) else { return }
        gulls?.removeFromParent()
        gullTile = tile
        guard let tile else { return }
        let group = SKNode()
        group.name = Self.gullsName
        group.position = IsoMath.screenPoint(forTile: tile)
        for index in 0 ..< BirdPlanner.gullCount {
            let radius = CGFloat(30 + index * 12)
            let circle = CGPath(
                ellipseIn: CGRect(x: -radius, y: -radius * 0.6 + 40, width: radius * 2, height: radius * 1.2),
                transform: nil
            )
            let gull = SKSpriteNode(texture: BirdArt.gull[0])
            BirdArt.flap(gull, frames: BirdArt.gull, phase: Double(index) * 0.11)
            let lap = 8 + Double(index) * 1.7
            gull.run(.repeatForever(.follow(circle, asOffset: false, orientToPath: false, duration: lap)))
            group.addChild(gull)
        }
        addChild(group)
    }
}

extension IsoWorldScene {
    func reconcileBirds(with snapshot: WorldSnapshot, now: TimeInterval) {
        if birdLayer.parent == nil { addChild(birdLayer) }
        birdLayer.reconcile(snapshot: snapshot, viewSize: size, reduceMotion: reduceMotion, now: now)
    }
}
