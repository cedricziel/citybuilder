import CityCore
import Foundation
import SpriteKit

public extension IsoWorldScene {
    /// The route the scene draws: in-progress while authoring, else the
    /// selected one. Spec: `rendering-2_5d` / Route overlay from the
    /// session.
    struct RouteOverlay: Equatable {
        public let waypoints: [Waypoint]
        /// Segment indices that cross land, drawn red.
        public let redSegments: Set<Int>
        /// A rejected tap to flash once.
        public let flash: TileCoordinate?

        public init(waypoints: [Waypoint], redSegments: Set<Int> = [], flash: TileCoordinate? = nil) {
            self.waypoints = waypoints
            self.redSegments = redSegments
            self.flash = flash
        }
    }
}

extension IsoWorldScene {
    func reconcileRoutes(with snapshot: WorldSnapshot) {
        if routeLayer.parent == nil {
            addChild(routeLayer)
        }
        routeLayer.show(routeOverlayProvider?(), snapshot: snapshot)
    }

    func reconcileShips(with snapshot: WorldSnapshot) {
        if shipLayer.parent == nil {
            addChild(shipLayer)
        }
        shipLayer.reconcile(snapshot: snapshot, viewSize: size)
    }
}

/// Legs, stop dots and the rejected-tap flash, between terrain and
/// buildings. Rebuilt only when the waypoints or red legs change.
final class RouteLayerNode: SKNode {
    static let legName = "route-leg"
    static let stopName = "route-stop"
    static let flashName = "route-flash"
    static let legColour = SKColor(white: 1, alpha: 0.85)
    static let redLegColour = SKColor(red: 1, green: 0.25, blue: 0.2, alpha: 0.95)

    /// The overlay on screen, without its flash.
    private var drawn: IsoWorldScene.RouteOverlay?

    override init() {
        super.init()
        zPosition = RouteLayerZPosition.routes
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    func show(_ overlay: IsoWorldScene.RouteOverlay?, snapshot: WorldSnapshot) {
        if let flash = overlay?.flash {
            addChild(Self.flashNode(at: flash))
        }
        let wanted = overlay.map { IsoWorldScene.RouteOverlay(waypoints: $0.waypoints, redSegments: $0.redSegments) }
        guard wanted != drawn else { return }
        drawn = wanted
        children.filter { $0.name != Self.flashName }.forEach { $0.removeFromParent() }
        guard let wanted else { return }
        let points = RoutePolylineProjector.projectedPoints(for: wanted.waypoints, snapshot: snapshot)
        for (index, pair) in zip(points, points.dropFirst()).enumerated() {
            let path = CGMutablePath()
            path.move(to: pair.0)
            path.addLine(to: pair.1)
            let leg = SKShapeNode(path: path)
            leg.name = Self.legName
            leg.lineWidth = 3
            leg.strokeColor = wanted.redSegments.contains(index) ? Self.redLegColour : Self.legColour
            addChild(leg)
        }
        for point in points {
            let stop = SKShapeNode(circleOfRadius: 5)
            stop.name = Self.stopName
            stop.position = point
            stop.fillColor = Self.legColour
            stop.strokeColor = .clear
            addChild(stop)
        }
    }

    /// A red tile diamond that fades out.
    private static func flashNode(at tile: TileCoordinate) -> SKShapeNode {
        let halfW = IsoMath.tileWidth / 2
        let halfH = IsoMath.tileHeight / 2
        let path = CGMutablePath()
        path.move(to: CGPoint(x: 0, y: halfH))
        path.addLine(to: CGPoint(x: halfW, y: 0))
        path.addLine(to: CGPoint(x: 0, y: -halfH))
        path.addLine(to: CGPoint(x: -halfW, y: 0))
        path.closeSubpath()
        let node = SKShapeNode(path: path)
        node.name = flashName
        node.position = IsoMath.screenPoint(forTile: tile)
        node.fillColor = redLegColour.withAlphaComponent(0.6)
        node.strokeColor = redLegColour
        node.run(.sequence([.fadeOut(withDuration: 0.6), .removeFromParent()]))
        return node
    }
}

/// One sprite per visible ship, facing from its heading. Spec:
/// `rendering-2_5d` / Ship sprite rendering, Ship facing selection,
/// Off-screen ship culling.
final class ShipLayerNode: SKNode {
    private struct ShipVisual {
        let node: SKSpriteNode
        var texture: String
        var target: CGPoint
    }

    private var visuals: [EntityID: ShipVisual] = [:]
    /// What a pass draws from; the snapshot changes at 10 Hz, the
    /// scene updates every frame.
    private struct PassKey: Equatable {
        let tick: UInt64
        let camera: Camera
        let viewSize: CGSize
    }

    private var lastPass: PassKey?

    override init() {
        super.init()
        zPosition = RouteLayerZPosition.ships
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    /// The texture name a ship's sprite shows, for tests.
    func textureName(of id: EntityID) -> String? {
        visuals[id]?.texture
    }

    func reconcile(snapshot: WorldSnapshot, viewSize: CGSize) {
        let pass = PassKey(tick: snapshot.tickCount, camera: snapshot.camera, viewSize: viewSize)
        guard pass != lastPass else { return }
        lastPass = pass
        let visible = snapshot.ships.filter {
            ShipCulling.isVisible(position: $0.position, camera: snapshot.camera, viewSize: viewSize)
        }
        let visibleIDs = Set(visible.map(\.id))
        for (id, visual) in visuals where !visibleIDs.contains(id) {
            visual.node.removeFromParent()
            visuals.removeValue(forKey: id)
        }
        for ship in visible {
            update(ship, tick: snapshot.tickCount)
        }
    }

    private func update(_ ship: Ship, tick: UInt64) {
        let frame = ship.state == .sailing ? Int(tick / 5 % 2) : 0
        let texture = ShipRenderMath.textureName(facing: ShipRenderMath.facing(forHeading: ship.heading), frame: frame)
        let target = ShipRenderMath.screenPoint(for: ship.position)
        guard var visual = visuals[ship.id] else {
            let node = SKSpriteNode(texture: SpriteAtlas.textureOrPlaceholder(named: texture))
            node.name = "ship-\(ship.id.raw)"
            node.anchorPoint = CGPoint(x: 0.5, y: 0.3)
            node.position = target
            visuals[ship.id] = ShipVisual(node: node, texture: texture, target: target)
            addChild(node)
            return
        }
        if visual.texture != texture {
            visual.texture = texture
            let atlasTexture = SpriteAtlas.textureOrPlaceholder(named: texture)
            visual.node.texture = atlasTexture
            visual.node.size = atlasTexture.size()
        }
        if visual.target != target {
            visual.target = target
            visual.node.removeAction(forKey: "move")
            visual.node.run(.move(to: target, duration: 0.1), withKey: "move")
        }
        visuals[ship.id] = visual
    }
}
