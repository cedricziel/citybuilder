// isokit: the wool → cloth chain. The sheep farm is a gather building (a fold of the ambient sheep beside a
// shepherd's hut), the weaver a craft building (a loom under a lean-to, cloth drying, a spinning wheel turning).
import AppKit
import SceneKit

enum Wool {
    static let fleece = NSColor(red: 0.84, green: 0.81, blue: 0.72, alpha: 1)
    static let hay = NSColor(red: 0.66, green: 0.58, blue: 0.34, alpha: 1)
    static let pasture = NSColor(red: 0.36, green: 0.44, blue: 0.22, alpha: 1)
    static let warp = NSColor(red: 0.88, green: 0.85, blue: 0.76, alpha: 1)
    static let madder = NSColor(red: 0.62, green: 0.24, blue: 0.20, alpha: 1)
    static let woad = NSColor(red: 0.24, green: 0.36, blue: 0.56, alpha: 1)
    static let weld = NSColor(red: 0.78, green: 0.66, blue: 0.28, alpha: 1)
}

extension Recipes {
    /// A rubble shepherd's hut under thatch, a post-and-rail fold over the front half with four sheep, a hay
    /// rack and fleece bales.
    static func sheepFarm(_ kit: Builder) {
        kit.hut(SCNVector3(0.8, 0, 0.8), SCNVector3(3.8, 0, 3.2), walls: .rubble, roof: .thatch)
        let lo = SCNVector3(0.5, 0, 3.8), hi = SCNVector3(7.6, 0, 7.6)
        kit.ground(lo, hi, .paint(Wool.pasture))
        kit.fence(from: lo, to: SCNVector3(hi.x, 0, lo.z))
        kit.fence(from: SCNVector3(hi.x, 0, lo.z), to: hi)
        kit.fence(from: SCNVector3(lo.x, 0, hi.z), to: hi)
        kit.fence(from: lo, to: SCNVector3(lo.x, 0, hi.z))
        kit.sheep(at: SCNVector3(2.2, 0, 5.4), yaw: 0.4, gait: .graze(0))
        kit.sheep(at: SCNVector3(4.4, 0, 6.6), yaw: -0.6, gait: .walk(0))
        kit.sheep(at: SCNVector3(5.6, 0, 4.8), yaw: 2.6, gait: .graze(0.5))
        kit.sheep(at: SCNVector3(3.4, 0, 4.6), yaw: 1.4, gait: .graze(0.25))
        kit.hayRack(at: SCNVector3(4.8, 0, 1.4))
        kit.woolBale(at: SCNVector3(5.2, 0, 2.6))
        kit.woolBale(at: SCNVector3(6.0, 0, 2.8))
    }

    /// A half-timbered hall under slate, a red lean-to over the loom on its east side, and dyed cloth drying on a
    /// line across the front yard. The spinning wheel by the door is the moving part.
    static func weaver(_ kit: Builder) {
        kit.hut(SCNVector3(0.8, 0, 0.8), SCNVector3(4.4, 0, 4.0), walls: .plaster, roof: .slate, framed: true)
        // The lean-to hides the east window, so the hall shows a second one, lit at night, on its south front.
        kit.window(Face.south(wallZ: 4.0), along: 3.3, y: 1.4)
        for depth in [CGFloat(1.0), 3.8] {
            kit.block(SCNVector3(6.4, 0, depth - 0.08), SCNVector3(6.56, 2.0, depth + 0.08), .timber)
        }
        kit.add(
            SCNBox(width: 2.4, height: 0.08, length: 3.2, chamferRadius: 0),
            Finish.paint(Trade.awning).material(),
            at: SCNVector3(5.45, 2.25, 2.4),
            euler: SCNVector3(0, 0, -0.25)
        )
        kit.loom(at: SCNVector3(4.7, 0, 3.1))
        kit.clothLine(from: SCNVector3(0.8, 0, 6.6), to: SCNVector3(6.8, 0, 6.6), colours: [Wool.madder, Wool.weld, Wool.woad])
        kit.woolBale(at: SCNVector3(5.4, 0, 4.6))
    }

    static func weaverWheel(_ kit: Builder, frame: Int) {
        kit.spinningWheel(at: SCNVector3(3.0, 0, 5.1), frame: frame)
    }
}

extension Builder {
    /// One of the ambient sheep, standing at `at` and turned by `yaw`.
    func sheep(at: SCNVector3, yaw: CGFloat, gait: Gait) {
        let local = Builder()
        local.beast(.sheep, gait)
        local.root.position = at
        local.root.eulerAngles = SCNVector3(0, yaw, 0)
        root.addChildNode(local.root)
    }

    func hayRack(at base: SCNVector3) {
        block(base, base + SCNVector3(1.4, 0.9, 0.5), .timber)
        add(
            SCNCone(topRadius: 0.2, bottomRadius: 0.5, height: 0.6),
            Finish.paint(Wool.hay).material(),
            at: base + SCNVector3(0.7, 1.2, 0.25)
        )
    }

    func woolBale(at base: SCNVector3) {
        add(
            SCNBox(width: 0.7, height: 0.55, length: 0.55, chamferRadius: 0.15),
            Finish.paint(Wool.fleece).material(),
            at: base + SCNVector3(0, 0.28, 0)
        )
    }

    /// A floor loom facing +z, built along x from `base`: posts, beams, the warp and the woven cloth.
    func loom(at base: SCNVector3, width: CGFloat = 1.8) {
        for x in [0, width] {
            block(base + SCNVector3(x - 0.06, 0, -0.06), base + SCNVector3(x + 0.06, 1.7, 0.06), .timber)
            block(base + SCNVector3(x - 0.06, 0, -0.9), base + SCNVector3(x + 0.06, 1.2, -0.78), .timber)
        }
        block(base + SCNVector3(-0.1, 1.6, -0.08), base + SCNVector3(width + 0.1, 1.72, 0.08), .timber)
        block(base + SCNVector3(-0.1, 0.9, -0.08), base + SCNVector3(width + 0.1, 1.0, 0.08), .timber)
        add(
            SCNBox(width: width - 0.2, height: 0.02, length: 0.85, chamferRadius: 0),
            Finish.paint(Wool.warp).material(),
            at: base + SCNVector3(width / 2, 1.05, -0.45),
            euler: SCNVector3(-0.15, 0, 0)
        )
        add(
            SCNBox(width: width - 0.2, height: 0.5, length: 0.03, chamferRadius: 0),
            Finish.paint(Wool.madder).material(),
            at: base + SCNVector3(width / 2, 0.68, 0)
        )
    }

    /// A great wheel on its bench, turning about its axle by an eighth of a turn per frame: with four spokes
    /// (eight arms) four frames make a full cycle.
    func spinningWheel(at base: SCNVector3, frame: Int) {
        block(base + SCNVector3(-0.8, 0.5, -0.12), base + SCNVector3(0.8, 0.62, 0.12), .wood)
        for x in [CGFloat(-0.7), 0.7] {
            block(base + SCNVector3(x - 0.05, 0, -0.05), base + SCNVector3(x + 0.05, 0.55, 0.05), .wood)
        }
        let hub = base + SCNVector3(0.35, 1.3, 0)
        block(hub + SCNVector3(-0.05, -0.8, -0.05), hub + SCNVector3(0.05, 0, 0.05), .wood)
        let wheel = SCNNode()
        wheel.position = hub
        wheel.eulerAngles = SCNVector3(0, CGFloat.pi / 2, CGFloat(frame) * .pi / 8)
        let rim = SCNNode(geometry: SCNTorus(ringRadius: 0.62, pipeRadius: 0.04))
        rim.geometry?.materials = [Finish.wood.material()]
        rim.eulerAngles = SCNVector3(CGFloat.pi / 2, 0, 0)
        wheel.addChildNode(rim)
        for spoke in 0 ..< 4 {
            let bar = SCNNode(geometry: SCNBox(width: 0.05, height: 1.22, length: 0.05, chamferRadius: 0))
            bar.geometry?.materials = [Finish.timber.material()]
            bar.eulerAngles = SCNVector3(0, 0, CGFloat(spoke) * .pi / 4)
            wheel.addChildNode(bar)
        }
        root.addChildNode(wheel)
        add(
            SCNCone(topRadius: 0.02, bottomRadius: 0.12, height: 0.35),
            Finish.paint(Wool.fleece).material(),
            at: base + SCNVector3(-0.6, 0.85, 0),
            euler: SCNVector3(0, 0, CGFloat.pi / 2)
        )
    }

    /// Two posts and cloth lengths hanging between them, one per colour.
    func clothLine(from start: SCNVector3, to end: SCNVector3, colours: [NSColor]) {
        for point in [start, end] {
            block(point + SCNVector3(-0.05, 0, -0.05), point + SCNVector3(0.05, 1.9, 0.05), .timber)
        }
        let delta = end - start
        let count = CGFloat(colours.count)
        let width: CGFloat = abs(delta.x) / count * 0.8 + 0.05
        let length: CGFloat = abs(delta.z) / count * 0.8 + 0.03
        for (index, colour) in colours.enumerated() {
            let along: CGFloat = (CGFloat(index) + 0.5) / count
            add(
                SCNBox(width: width, height: 1.0, length: length, chamferRadius: 0),
                Finish.paint(colour).material(),
                at: start + delta * along + SCNVector3(0, 1.35, 0)
            )
        }
    }
}
