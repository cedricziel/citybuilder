// isokit: yard props and clutter that make a building look lived in.
import AppKit
import SceneKit

extension Builder {
    /// Post-and-rail fence between two ground points.
    func fence(from start: SCNVector3, to end: SCNVector3, height: CGFloat = 0.9) {
        let delta = end - start
        let length = delta.length
        let posts = max(Int(length / 1.2), 1)
        for index in 0 ... posts {
            let point = start + delta * (CGFloat(index) / CGFloat(posts))
            block(SCNVector3(point.x - 0.06, 0, point.z - 0.06), SCNVector3(point.x + 0.06, height, point.z + 0.06), .timber)
        }
        let yaw = -atan2(delta.z, delta.x)
        for railY in [height * 0.45, height * 0.85] {
            add(
                SCNBox(width: length, height: 0.07, length: 0.05, chamferRadius: 0),
                Finish.wood.material(),
                at: start + delta * 0.5 + SCNVector3(0, railY, 0),
                euler: SCNVector3(0, yaw, 0)
            )
        }
    }

    /// A pyramid of logs; `alongX` = log axis.
    func logStack(at base: SCNVector3, length: CGFloat, rows: Int, alongX: Bool) {
        let radius: CGFloat = 0.16
        for row in 0 ..< rows {
            for index in 0 ..< (rows - row + 1) {
                let across = CGFloat(index) * radius * 2 + CGFloat(row) * radius
                let log = SCNCylinder(radius: radius, height: length)
                let offset = alongX ? SCNVector3(0, 0, across) : SCNVector3(across, 0, 0)
                let euler = alongX ? SCNVector3(0, 0, CGFloat.pi / 2) : SCNVector3(CGFloat.pi / 2, 0, 0)
                add(log, Finish.wood.material(), at: base + offset + SCNVector3(0, radius + CGFloat(row) * radius * 1.7, 0), euler: euler)
            }
        }
    }

    func plankStack(at base: SCNVector3, length: CGFloat, layers: Int) {
        for layer in 0 ..< layers {
            let lo = base + SCNVector3(0, CGFloat(layer) * 0.12, 0)
            block(lo, lo + SCNVector3(length, 0.1, 1.0), .planks)
        }
    }

    func barrel(at base: SCNVector3) {
        add(SCNCylinder(radius: 0.28, height: 0.75), Finish.wood.material(), at: base + SCNVector3(0, 0.375, 0))
    }

    func crate(at base: SCNVector3) {
        block(base + SCNVector3(-0.3, 0, -0.3), base + SCNVector3(0.3, 0.55, 0.3), .planks)
    }

    func sapling(at base: SCNVector3, size: CGFloat = 1) {
        add(SCNCylinder(radius: 0.04 * size, height: 0.5 * size), Finish.timber.material(), at: base + SCNVector3(0, 0.25 * size, 0))
        add(
            SCNCone(topRadius: 0, bottomRadius: 0.32 * size, height: 1.0 * size),
            Finish.paint(NSColor(red: 0.30, green: 0.48, blue: 0.20, alpha: 1)).material(),
            at: base + SCNVector3(0, 0.9 * size, 0)
        )
    }

    func stump(at base: SCNVector3) {
        add(SCNCylinder(radius: 0.3, height: 0.4), Finish.wood.material(), at: base + SCNVector3(0, 0.2, 0))
    }

    func well(at base: SCNVector3) {
        add(SCNTube(innerRadius: 0.5, outerRadius: 0.75, height: 0.8), Finish.rubble.material(repeatU: 2), at: base + SCNVector3(0, 0.4, 0))
        add(
            SCNCylinder(radius: 0.5, height: 0.05),
            Finish.paint(NSColor(red: 0.16, green: 0.26, blue: 0.30, alpha: 1)).material(),
            at: base + SCNVector3(0, 0.6, 0)
        )
        for side in [CGFloat(-1), 1] {
            block(base + SCNVector3(side * 0.7 - 0.06, 0.8, -0.06), base + SCNVector3(side * 0.7 + 0.06, 2.0, 0.06), .timber)
        }
        block(base + SCNVector3(-0.85, 1.95, -0.5), base + SCNVector3(0.85, 2.1, 0.5), .thatch)
    }

    /// Market stall: table plus a sloped cloth awning.
    func stall(at base: SCNVector3, cloth: NSColor) {
        block(base + SCNVector3(-0.8, 0.75, -0.5), base + SCNVector3(0.8, 0.85, 0.5), .wood)
        for corner in [SCNVector3(-0.75, 0, 0.45), SCNVector3(0.75, 0, 0.45), SCNVector3(-0.75, 0, -0.45), SCNVector3(0.75, 0, -0.45)] {
            block(base + corner - SCNVector3(0.04, 0, 0.04), base + corner + SCNVector3(0.04, 1.7, 0.04), .timber)
        }
        add(
            SCNBox(width: 1.9, height: 0.05, length: 1.3, chamferRadius: 0),
            Finish.paint(cloth).material(),
            at: base + SCNVector3(0, 1.75, 0),
            euler: SCNVector3(0.25, 0, 0)
        )
        for index in 0 ..< 4 {
            let produce = SCNSphere(radius: 0.12)
            add(
                produce,
                Finish.paint(NSColor(red: 0.75, green: 0.45, blue: 0.15, alpha: 1)).material(),
                at: base + SCNVector3(-0.5 + CGFloat(index) * 0.3, 0.95, 0.1)
            )
        }
    }

    /// Paving or yard surface just above the ground.
    func ground(_ lo: SCNVector3, _ hi: SCNVector3, _ finish: Finish) {
        block(SCNVector3(lo.x, 0, lo.z), SCNVector3(hi.x, 0.04, hi.z), finish, metresPerRepeat: 3)
    }

    /// The building plot: a slab over the whole footprint, 3 cm below yard slabs so they never z-fight.
    /// It runs 12 cm past the two front edges, so the cell's bottom edge crops it and the bottom row
    /// is solidly opaque; a diamond tip alone is ~2 px wide and its alpha flickers between renders.
    func plot(width: CGFloat, depth: CGFloat, _ finish: Finish) {
        block(SCNVector3(0, -0.02, 0), SCNVector3(width + 0.12, 0.01, depth + 0.12), finish, metresPerRepeat: 3)
    }
}
