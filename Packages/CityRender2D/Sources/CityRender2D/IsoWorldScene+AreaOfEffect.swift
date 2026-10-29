import CityCore
import SpriteKit

/// A corner of the tile grid: tile (x, y) spans corners x ... x + 1 and y ... y + 1.
struct GridCorner: Hashable, Comparable {
    let x: Int
    let y: Int

    static func < (lhs: GridCorner, rhs: GridCorner) -> Bool {
        (lhs.y, lhs.x) < (rhs.y, rhs.x)
    }
}

/// The area the ghost or the selected building reaches, on the ground: a gold outline over a dark
/// under-stroke with a faint gold tint, a stronger tint on the open grass it would plant, and its
/// trees or rock in reach brightened on their own nodes. Three nodes at most, whatever the area's
/// size. Spec: `rendering-2_5d` / Areas of effect while placing and selecting.
extension IsoWorldScene {
    static let areaUnderStrokeNodeName = "area-under-stroke"
    static let areaOutlineNodeName = "area-outline"
    static let areaTargetFillNodeName = "area-target-fill"
    /// Above the ground, its shading and the roads (2); below the routes (5) and everything that
    /// stands, so trees in front of the area cover its outline.
    static let areaLayerZ: CGFloat = 4
    static let areaUnderStrokeColour = SKColor(red: 20 / 255, green: 14 / 255, blue: 0, alpha: 0.59)
    /// Lifts a tree or rock in reach toward a warm light. A colour blend can only darken a texture,
    /// so they share this one shader instead; it adds no node.
    static let areaObjectShader = SKShader(source: """
    void main() {
        vec4 c = SKDefaultShading();
        gl_FragColor = vec4(min(c.rgb * 1.3 + c.a * vec3(0.12, 0.10, 0.02), vec3(c.a)), c.a);
    }
    """)

    /// Gold for what a building works, teal for what it serves (a fire watch's reach), amber for
    /// what an event threatens (`add-event-counterplay`).
    static func areaColour(_ style: AreaOfEffect.Style) -> SKColor {
        switch style {
        case .reach: ringColour
        case .serves: SKColor(red: 0.36, green: 0.82, blue: 0.78, alpha: 0.85)
        case .threat: SKColor(red: 0.96, green: 0.62, blue: 0.16, alpha: 0.85)
        }
    }

    func reconcileAreaOfEffect(with snapshot: WorldSnapshot) {
        if areaLayer.parent == nil {
            areaLayer.zPosition = Self.areaLayerZ
            addChild(areaLayer)
        }
        let wanted = areaOfEffectProvider?()
        if wanted != shownArea {
            brightenObjects(of: shownArea, with: nil)
            shownArea = wanted
            drawArea(wanted, in: snapshot)
            areaBrightenedAfterPass = nil
        }
        // A terrain pass builds tiles' nodes again on a pan or a new season: brighten after each.
        let pass = spriteReconcileCounts.terrainPasses
        guard areaBrightenedAfterPass != pass else { return }
        areaBrightenedAfterPass = pass
        brightenObjects(of: shownArea, with: Self.areaObjectShader)
    }

    private func drawArea(_ area: AreaOfEffect?, in snapshot: WorldSnapshot) {
        areaLayer.removeAllChildren()
        guard let area, !area.tiles.isEmpty else { return }
        let outline = Self.outlinePath(around: area.tiles)
        let under = SKShapeNode(path: outline)
        under.name = Self.areaUnderStrokeNodeName
        under.strokeColor = Self.areaUnderStrokeColour
        under.lineWidth = 4
        under.lineJoin = .round
        areaLayer.addChild(under)
        let colour = Self.areaColour(area.style)
        let ring = SKShapeNode(path: outline)
        ring.name = Self.areaOutlineNodeName
        ring.strokeColor = colour
        ring.fillColor = colour.withAlphaComponent(0.06)
        ring.lineWidth = 2
        ring.lineJoin = .round
        areaLayer.addChild(ring)
        // Trees and rock show their reach on their own nodes; the rest, a forester's grass, is tinted.
        let open = area.targets.filter { !TerrainObject.kinds.contains(snapshot.terrain(at: $0) ?? .water) }
        guard !open.isEmpty else { return }
        let fill = SKShapeNode(path: Self.outlinePath(around: Set(open)))
        fill.name = Self.areaTargetFillNodeName
        fill.strokeColor = .clear
        fill.fillColor = colour.withAlphaComponent(0.16)
        areaLayer.addChild(fill)
    }

    /// Gives every target's clump that is on screen `shader`, or takes it away.
    private func brightenObjects(of area: AreaOfEffect?, with shader: SKShader?) {
        for target in area?.targets ?? [] {
            guard let clump = objectNode(at: target), clump.shader !== shader else { continue }
            clump.shader = shader
        }
    }

    /// The tree or rock node on a tile, if the tile is on screen: the tile's own node over plain
    /// ground, otherwise its ground node's child.
    func objectNode(at coord: TileCoordinate) -> SKSpriteNode? {
        guard let spec = terrainSpecs[coord], let node = presentSprites[spec] else { return nil }
        let clump = node.name == Self.terrainObjectNodeName ? node : node.childNode(withName: Self.terrainObjectNodeName)
        return clump as? SKSpriteNode
    }

    /// The boundary of `tiles` on screen, one closed subpath per loop. Each loop runs with the area
    /// on the same side, so a hole in the area stays unfilled.
    static func outlinePath(around tiles: Set<TileCoordinate>) -> CGPath {
        let path = CGMutablePath()
        for loop in outlineLoops(around: tiles) {
            path.addLines(between: loop.map { corner in
                IsoMath.screenPoint(forTileFractionalX: Double(corner.x) - 0.5, fractionalY: Double(corner.y) - 0.5)
            })
            path.closeSubpath()
        }
        return path
    }

    /// The boundary of `tiles` as closed loops of grid corners: every tile edge with no neighbour in
    /// the set, chained end to start. Loops start at their smallest corner, in corner order.
    static func outlineLoops(around tiles: Set<TileCoordinate>) -> [[GridCorner]] {
        var outgoing: [GridCorner: [GridCorner]] = [:]
        for tile in tiles {
            let (x, y) = (tile.x, tile.y)
            // Clockwise in tile space: edge i runs from corner i to corner i + 1, against neighbour i.
            let corners = [GridCorner(x: x, y: y), GridCorner(x: x + 1, y: y), GridCorner(x: x + 1, y: y + 1), GridCorner(x: x, y: y + 1)]
            let neighbours = [
                TileCoordinate(x: x, y: y - 1), TileCoordinate(x: x + 1, y: y), TileCoordinate(x: x, y: y + 1), TileCoordinate(
                    x: x - 1,
                    y: y
                )
            ]
            for side in 0 ..< 4 where !tiles.contains(neighbours[side]) {
                outgoing[corners[side], default: []].append(corners[(side + 1) % 4])
            }
        }
        var loops: [[GridCorner]] = []
        for start in outgoing.keys.sorted() {
            while let first = outgoing[start]?.popLast() {
                var loop = [start]
                var corner = first
                while corner != start {
                    loop.append(corner)
                    guard let next = outgoing[corner]?.popLast() else { break }
                    corner = next
                }
                loops.append(loop)
            }
        }
        return loops
    }
}
