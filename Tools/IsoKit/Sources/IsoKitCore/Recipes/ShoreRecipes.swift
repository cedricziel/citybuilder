// isokit: the shore family. The port and shipyard straddle the shoreline on a 2 x 3 footprint and
// come in four facings; the ship sails in eight. Facings move the geometry, never the camera or
// the sun, so every facing lights the same way (design, open question on shore orientations).
import AppKit
import SceneKit

enum Shore {
    /// Pitch-dark hull below the waterline.
    static let tar = NSColor(red: 0.22, green: 0.17, blue: 0.13, alpha: 1)
    static let rope = NSColor(red: 0.62, green: 0.52, blue: 0.36, alpha: 1)
}

/// Which way the sea lies from a shore building's land side, as the renderer names it
/// (`ShoreOrientation`, from the land-face centroid toward the sea-face centroid; +z is south).
enum SeaSide: String, CaseIterable {
    // swiftlint:disable:next identifier_name
    case n, e, s, w
}

/// A shore building's own frame: `out` runs from the landward edge (0) to the seaward edge (`length`),
/// `along` the shore from 0 to `width`, ending on an edge the camera sees (+x or +z). The footprint
/// is two columns by three rows whichever way it faces, so north and south facings are 12 m deep
/// and east and west ones 8 m. The shoreline is taken to cross the middle.
struct ShoreFrame {
    let side: SeaSide

    var length: CGFloat {
        side == .n || side == .s ? 12 : 8
    }

    var width: CGFloat {
        side == .n || side == .s ? 8 : 12
    }

    var shore: CGFloat {
        length / 2
    }

    /// The ridge of a roof running along the shore lies along x for north and south facings.
    var shoreAlongX: Bool {
        side == .n || side == .s
    }

    /// The landward and seaward ends of a slab: 12 cm past the footprint where that edge faces the
    /// camera (the plot rule), flush where it faces away, or it would poke out of the cell.
    var landEdge: CGFloat {
        side == .n || side == .w ? -0.12 : 0
    }

    var seaEdge: CGFloat {
        side == .s || side == .e ? length + 0.12 : length
    }

    /// The shipyard's slipway: 4.4 m wide, beside the visible edge.
    var slipway: ClosedRange<CGFloat> {
        (width - 5.0) ... (width - 0.6)
    }

    func point(_ out: CGFloat, _ y: CGFloat, _ along: CGFloat) -> SCNVector3 {
        switch side {
        case .s: SCNVector3(along, y, out)
        case .n: SCNVector3(along, y, length - out)
        case .e: SCNVector3(out, y, along)
        case .w: SCNVector3(length - out, y, along)
        }
    }

    /// The world box between two frame corners.
    func box(out: ClosedRange<CGFloat>, y: ClosedRange<CGFloat>, along: ClosedRange<CGFloat>) -> (SCNVector3, SCNVector3) {
        let near = point(out.lowerBound, y.lowerBound, along.lowerBound), far = point(out.upperBound, y.upperBound, along.upperBound)
        return (SCNVector3(min(near.x, far.x), near.y, min(near.z, far.z)), SCNVector3(max(near.x, far.x), far.y, max(near.z, far.z)))
    }
}

extension Recipes {
    static let shore: [Recipe] = SeaSide.allCases.flatMap { side in
        let frame = ShoreFrame(side: side)
        return [
            Recipe(
                id: "building-port-\(side.rawValue)",
                cell: SpriteCell(footprint: 2, rows: 3, heightPx: 128),
                operationalFrames: 2,
                customStages: true,
                plot: nil
            ) { kit, stage in
                kit.quay(frame, to: frame.shore + 0.4)
                kit.pier(frame, along: frame.width - 2.8 ... frame.width + 0.12)
                kit.staged(stage) { port($0, frame) }
            },
            Recipe(
                id: "building-shipyard-\(side.rawValue)",
                cell: SpriteCell(footprint: 2, rows: 3, heightPx: 128),
                operationalFrames: 2,
                moving: MovingPart(name: "hull") { kit, index in shipyardHull(kit, frame, planked: index) },
                customStages: true,
                plot: nil
            ) { kit, stage in
                kit.quay(frame, to: frame.shore + 0.2)
                kit.slipway(frame)
                kit.staged(stage) { shipyard($0, frame) }
            }
        ]
    } + ShipFacing.allCases.map { facing in
        Recipe(
            id: "ship-\(facing.rawValue)",
            entry: "ship",
            cell: SpriteCell(footprint: 1, heightPx: 72),
            constructionFrames: 0,
            operationalFrames: 2,
            moving: MovingPart(name: "sail") { kit, index in shipSail(kit, facing, luff: index) },
            plot: nil,
            unit: true
        ) { kit, _ in ship(kit, facing) }
    }

    /// On the quay: a timber-framed warehouse on the land side, a crane at the quay edge, and cargo.
    /// The quay and the pier come first, so the construction stages show them from the start.
    static func port(_ kit: Builder, _ frame: ShoreFrame) {
        let (lo, hi) = frame.box(out: 1.1 ... frame.shore - 1.0, y: 0.5 ... 3.3, along: 1.0 ... frame.width - 3.4)
        kit.shed(lo, hi, walls: .plaster, roof: .tile)
        kit.timberFrame(Face.south(wallZ: hi.z), span: lo.x ... hi.x, base: 0.5, height: 2.8, posts: 4)
        kit.timberFrame(Face.east(wallX: hi.x), span: lo.z ... hi.z, base: 0.5, height: 2.8, posts: 4)
        kit.door(Face.south(wallZ: hi.z), along: (lo.x + hi.x) / 2, base: 0.5, width: 1.4, height: 2.0)
        kit.door(Face.east(wallX: hi.x), along: (lo.z + hi.z) / 2, base: 0.5, width: 1.4, height: 2.0)
        kit.crane(frame, at: frame.shore - 0.2, along: frame.width - 3.6)
        kit.cargo(at: frame.point(1.4, 0.5, frame.width - 2.0))
        kit.barrel(at: frame.point(frame.shore - 1.0, 0.5, frame.width - 1.0))
    }

    /// Beside the slipway: a plank shed on the land side, and logs.
    static func shipyard(_ kit: Builder, _ frame: ShoreFrame) {
        let (lo, hi) = frame.box(out: 0.8 ... frame.shore - 0.4, y: 0.5 ... 2.7, along: 0.8 ... frame.slipway.lowerBound - 0.6)
        kit.shed(lo, hi, walls: .planks, roof: .planks)
        kit.logStack(at: frame.point(0.6, 0.5, frame.width - 1.4), length: 1.8, rows: 2, alongX: frame.shoreAlongX)
    }

    /// A hull on the slipway's cradle: keel and ribs, with two strakes (frame 0) or four (frame 1).
    static func shipyardHull(_ kit: Builder, _ frame: ShoreFrame, planked: Int) {
        let centre = (frame.slipway.lowerBound + frame.slipway.upperBound) / 2
        let start = frame.shore - 2.6, end = min(frame.shore + 3.4, frame.length - 0.4)
        let beam = { (out: CGFloat) -> CGFloat in 1.25 * sin(.pi * (out - start) / (end - start)).squareRoot() }
        let (keelLo, keelHi) = frame.box(out: start ... end, y: 0.6 ... 1.0, along: centre - 0.15 ... centre + 0.15)
        kit.block(keelLo, keelHi, .timber)
        let ribs = 7
        for index in 1 ..< ribs {
            let out = start + (end - start) * CGFloat(index) / CGFloat(ribs)
            for side in [CGFloat(-1), 1] {
                let along = centre + side * beam(out)
                let (lo, hi) = frame.box(out: out - 0.08 ... out + 0.08, y: 0.9 ... 2.4, along: along - 0.08 ... along + 0.08)
                kit.block(lo, hi, .timber)
            }
        }
        for strake in 0 ..< (planked == 0 ? 2 : 4) {
            let y = 1.0 + 0.32 * CGFloat(strake)
            for index in 0 ..< ribs {
                let u0 = start + (end - start) * CGFloat(index) / CGFloat(ribs), u1 = u0 + (end - start) / CGFloat(ribs)
                for side in [CGFloat(-1), 1] {
                    let along = centre + side * (beam((u0 + u1) / 2) + 0.06)
                    let (lo, hi) = frame.box(out: u0 ... u1, y: y ... y + 0.3, along: along - 0.05 ... along + 0.05)
                    kit.block(lo, hi, .wood)
                }
            }
        }
    }
}

// MARK: ship

/// The eight facings a ship sails in, as the renderer names them (`ShipFacing`).
enum ShipFacing: String, CaseIterable {
    // swiftlint:disable:next identifier_name
    case n, ne, e, se, s, sw, w, nw

    /// Yaw that turns a hull built bow-to-+x toward this facing (north is -z, east +x).
    var yaw: CGFloat {
        let index = CGFloat(Self.allCases.firstIndex(of: self) ?? 0)
        return .pi / 2 - index * .pi / 4
    }
}

extension Recipes {
    /// Where the hull's centre sits: up-screen of the tile centre, at the renderer's ship anchor
    /// (0.5, 0.3), 21.6 pt up a 72 pt cell.
    static let shipCentre = SCNVector3(1.3, 0, 1.3)

    /// A single-masted cog: a tarred lower hull, plank strakes, pointed ends, an aft castle and a mast.
    static func ship(_ kit: Builder, _ facing: ShipFacing) {
        kit.yawed(facing.yaw, about: shipCentre) { hull in
            hull.block(SCNVector3(-1.9, -0.1, -0.8), SCNVector3(1.9, 0.45, 0.8), .paint(Shore.tar))
            hull.block(SCNVector3(-2.1, 0.45, -0.9), SCNVector3(2.1, 1.05, 0.9), .timber)
            for end in [CGFloat(-1), 1] {
                hull.add(
                    SCNBox(width: 1.2, height: 0.95, length: 1.2, chamferRadius: 0), Finish.timber.material(),
                    at: SCNVector3(end * 2.05, 0.55, 0), euler: SCNVector3(0, CGFloat.pi / 4, 0)
                )
            }
            hull.block(SCNVector3(-1.95, 0.95, -0.75), SCNVector3(1.95, 1.0, 0.75), .wood)
            hull.block(SCNVector3(-2.2, 1.0, -0.85), SCNVector3(-1.2, 1.55, 0.85), .planks)
            hull.add(SCNCylinder(radius: 0.09, height: 3.6), Finish.timber.material(), at: SCNVector3(0.2, 2.8, 0))
            hull.add(
                SCNCylinder(radius: 0.05, height: 2.6), Finish.timber.material(),
                at: SCNVector3(0.3, 4.3, 0), euler: SCNVector3(CGFloat.pi / 2, 0, 0)
            )
        }
    }

    /// The square sail under the yard, drawing (frame 0) or easing and slacking aft (frame 1).
    static func shipSail(_ kit: Builder, _ facing: ShipFacing, luff: Int) {
        kit.yawed(facing.yaw, about: shipCentre) { rig in
            let slack: CGFloat = luff == 0 ? 0 : 1
            rig.add(
                SCNBox(width: 0.06, height: 2.3, length: 2.4 - 0.15 * slack, chamferRadius: 0),
                Finish.paint(Palette.sailcloth).material(),
                at: SCNVector3(0.42 - 0.12 * slack, 3.05, 0), euler: SCNVector3(0, 0, 0.08 + 0.1 * slack)
            )
        }
    }
}

// MARK: shore parts

extension Builder {
    /// A grey stone quay over the land side, out to `edge`, 0.5 m above the water.
    func quay(_ frame: ShoreFrame, to edge: CGFloat) {
        let (lo, hi) = frame.box(out: frame.landEdge ... edge, y: -0.02 ... 0.5, along: 0 ... frame.width + 0.12)
        block(lo, hi, .rock)
    }

    /// A stone slipway stepping down into the water, with timber rails for the cradle.
    func slipway(_ frame: ShoreFrame) {
        let slip = frame.slipway, steps = 6
        for index in 0 ..< steps {
            let start = frame.shore - 1.0 + (frame.length - frame.shore + 1.12) * CGFloat(index) / CGFloat(steps)
            let (lo, hi) = frame.box(
                out: start ... frame.seaEdge,
                y: -0.02 ... 0.52 - 0.08 * CGFloat(index),
                along: slip.lowerBound ... frame.width + 0.12
            )
            block(lo, hi, .rock)
        }
        for rail in [slip.lowerBound + 0.9, slip.upperBound - 0.9] {
            let (lo, hi) = frame.box(out: 0.4 ... frame.length - 0.4, y: 0.52 ... 0.6, along: rail - 0.1 ... rail + 0.1)
            block(lo, hi, .timber)
        }
    }

    /// A plank deck on pilings from the quay to the seaward edge.
    func pier(_ frame: ShoreFrame, along span: ClosedRange<CGFloat>) {
        let (lo, hi) = frame.box(out: frame.shore ... frame.seaEdge, y: 0.42 ... 0.56, along: span)
        block(lo, hi, .planks)
        var out = frame.shore + 1.2
        while out < frame.length {
            for along in [span.lowerBound + 0.2, span.upperBound - 0.32] {
                add(SCNCylinder(radius: 0.13, height: 0.9), Finish.timber.material(), at: frame.point(out, 0.3, along))
            }
            out += 1.6
        }
        add(
            SCNCylinder(radius: 0.12, height: 0.5),
            Finish.timber.material(),
            at: frame.point(frame.length - 0.4, 0.8, span.lowerBound + 0.3)
        )
    }

    /// A timber crane: a post at the quay edge with a jib reaching over the water and a hanging crate.
    func crane(_ frame: ShoreFrame, at out: CGFloat, along: CGFloat) {
        let (lo, hi) = frame.box(out: out - 0.18 ... out + 0.18, y: 0.5 ... 5.0, along: along - 0.18 ... along + 0.18)
        block(lo, hi, .timber)
        let (jibLo, jibHi) = frame.box(out: out - 0.6 ... out + 2.4, y: 4.6 ... 4.85, along: along - 0.12 ... along + 0.12)
        block(jibLo, jibHi, .timber)
        let (ropeLo, ropeHi) = frame.box(out: out + 2.2 ... out + 2.26, y: 2.3 ... 4.6, along: along - 0.03 ... along + 0.03)
        block(ropeLo, ropeHi, .paint(Shore.rope))
        crate(at: frame.point(out + 2.23, 1.75, along))
    }

    /// Builds `body` finished, or cut to construction stage `stage` with scaffold on its own corners;
    /// the shore buildings stage their works this way so the full-footprint quay gets no scaffold.
    func staged(_ stage: Stage, _ body: (Builder) -> Void) {
        guard case let .constructing(index) = stage else { return body(self) }
        let works = Builder()
        body(works)
        ConstructionStages.cut(works.root, frame: index, frames: 3)
        for child in works.root.childNodes {
            root.addChildNode(child)
        }
    }

    /// A plain building between `lo` and `hi` (y from base to eave) with its ridge along the longer side.
    func shed(_ lo: SCNVector3, _ hi: SCNVector3, walls: Finish, roof: Finish) {
        block(lo, hi, walls)
        gableRoof(RoofSpec(
            lo: SCNVector3(lo.x, hi.y, lo.z), hi: hi, pitchDegrees: 40, finish: roof, gableFinish: walls,
            ridgeAlongX: hi.x - lo.x >= hi.z - lo.z
        ))
    }

    /// Builds `body` in a frame turned by `yaw` about the vertical axis through `centre`.
    func yawed(_ yaw: CGFloat, about centre: SCNVector3, _ body: (Builder) -> Void) {
        let local = Builder()
        body(local)
        let pivot = SCNNode()
        pivot.position = centre
        pivot.eulerAngles = SCNVector3(0, yaw, 0)
        for child in local.root.childNodes {
            pivot.addChildNode(child)
        }
        root.addChildNode(pivot)
    }
}
