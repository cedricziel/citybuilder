// isokit: people. A figure is built from primitives facing +x, then yawed to its facing.
// Sizes in metres for a 1.7 m adult; `Figure.scale` grows the whole figure.
import AppKit
import SceneKit
import simd

/// Muted natural dyes. The warm sun saturates them, so they sit greyer than the target.
enum Cloth {
    static let linen = NSColor(red: 0.80, green: 0.77, blue: 0.68, alpha: 1)
    /// Light enough that the worker reads against the earth roads at zoom 1.
    static let madder = NSColor(red: 0.62, green: 0.36, blue: 0.30, alpha: 1)
    static let woad = NSColor(red: 0.30, green: 0.37, blue: 0.47, alpha: 1)
    static let weld = NSColor(red: 0.50, green: 0.47, blue: 0.34, alpha: 1)
    static let walnut = NSColor(red: 0.33, green: 0.25, blue: 0.19, alpha: 1)
    static let fustian = NSColor(red: 0.45, green: 0.42, blue: 0.36, alpha: 1)
    static let leather = NSColor(red: 0.20, green: 0.14, blue: 0.10, alpha: 1)
    static let felt = NSColor(red: 0.26, green: 0.22, blue: 0.20, alpha: 1)
    static let straw = NSColor(red: 0.62, green: 0.56, blue: 0.42, alpha: 1)
    static let hair = NSColor(red: 0.22, green: 0.16, blue: 0.12, alpha: 1)
    static let skin = NSColor(red: 0.74, green: 0.56, blue: 0.45, alpha: 1)
    static let burlap = NSColor(red: 0.52, green: 0.48, blue: 0.40, alpha: 1)
    static let bark = NSColor(red: 0.34, green: 0.28, blue: 0.22, alpha: 1)
    static let stave = NSColor(red: 0.42, green: 0.31, blue: 0.21, alpha: 1)
    static let deal = NSColor(red: 0.50, green: 0.42, blue: 0.31, alpha: 1)
    static let loaf = NSColor(red: 0.55, green: 0.40, blue: 0.26, alpha: 1)
    static let wicker = NSColor(red: 0.46, green: 0.37, blue: 0.26, alpha: 1)
}

/// What a figure carries.
enum Load {
    case none, basket, sack, crate, barrel, logs, push, yoke
}

enum Headwear {
    case cap, straw, coif, hood
}

struct Figure {
    var scale: CGFloat = 1
    /// Head radius relative to a realistic 1/7.5 head; > 1 reads better at sprite scale.
    var head: CGFloat = 1
    /// Limb thickness factor.
    var limbs: CGFloat = 1
    var tunic = Cloth.madder
    var hose = Cloth.fustian
    var skirt: NSColor?
    var apron: NSColor?
    var headwear = Headwear.cap
    var load = Load.none
}

/// The screen diagonals walkers face, as the renderer names them (`SpriteAtlas.WalkerFacing`).
enum WalkerFacing: String, CaseIterable {
    case ne, nw, se, sw

    /// Yaw that turns a figure built facing +x (screen south-east) toward this facing.
    var yaw: CGFloat {
        switch self {
        case .se: 0
        case .ne: .pi / 2
        case .nw: .pi
        case .sw: -.pi / 2
        }
    }
}

extension Builder {
    /// A cylinder between two points.
    func limb(_ from: SCNVector3, _ to: SCNVector3, radius: CGFloat, _ colour: NSColor) {
        let delta = to - from
        let node = add(SCNCylinder(radius: radius, height: delta.length), Finish.paint(colour).material(), at: from + delta * 0.5)
        let dir = simd_normalize(simd_float3(Float(delta.x), Float(delta.y), Float(delta.z)))
        node.simdOrientation = simd_quatf(from: simd_float3(0, 1, 0), to: dir)
    }

    @discardableResult
    func ball(_ centre: SCNVector3, radius: CGFloat, _ colour: NSColor, scale: SCNVector3 = SCNVector3(1, 1, 1)) -> SCNNode {
        let node = add(SCNSphere(radius: radius), Finish.paint(colour).material(), at: centre)
        node.scale = scale
        return node
    }

    /// One walking figure at `phase` (0..<1 through the gait), feet on y = 0 at the origin, facing +x.
    func figure(_ fig: Figure, phase: CGFloat) {
        let angle = phase * 2 * .pi
        let bob = 0.025 * cos(2 * angle)
        let hip: CGFloat = 0.86, shoulder: CGFloat = 1.40, limbR = 0.062 * fig.limbs
        // Legs: the thigh swings with the phase and the knee bends most as the leg passes under the hips on
        // its forward swing. At phase 0 the legs are together and the arms hang, the right knee eased, so
        // frame 0 doubles as a relaxed standing pose; at phase 1/2 the left knee eases instead.
        for (side, offset) in [(CGFloat(1), CGFloat(0)), (-1, .pi)] {
            let legPhase = angle + offset
            let thigh = 0.36 * sin(legPhase)
            let knee = thigh - 0.5 * max(0, cos(legPhase))
            let hipPoint = SCNVector3(0, hip + bob, side * 0.1)
            let kneePoint = hipPoint + SCNVector3(sin(thigh) * 0.44, -cos(thigh) * 0.44, 0)
            let ankle = kneePoint + SCNVector3(sin(knee) * 0.40, -cos(knee) * 0.40, 0)
            if fig.skirt == nil {
                limb(hipPoint, kneePoint, radius: limbR * 1.15, fig.hose)
                limb(kneePoint, ankle, radius: limbR, fig.hose)
            }
            block(ankle + SCNVector3(-0.06, -0.06, -0.05), ankle + SCNVector3(0.13, 0.04, 0.05), .paint(Cloth.leather))
        }
        // Body.
        let torso = add(
            SCNCone(topRadius: 0.17 * fig.limbs, bottomRadius: 0.21 * fig.limbs, height: 0.66),
            Finish.paint(fig.tunic).material(),
            at: SCNVector3(0, 1.10 + bob, 0)
        )
        torso.scale = SCNVector3(0.72, 1, 1)
        if let skirt = fig.skirt {
            let sway = 0.04 * sin(angle)
            let hem = add(
                SCNCone(topRadius: 0.17, bottomRadius: 0.30, height: 0.86),
                Finish.paint(skirt).material(),
                at: SCNVector3(sway, 0.50, 0)
            )
            hem.scale = SCNVector3(0.85, 1, 1)
            if let apron = fig.apron {
                add(
                    SCNBox(width: 0.03, height: 0.66, length: 0.26, chamferRadius: 0),
                    Finish.paint(apron).material(),
                    at: SCNVector3(0.21 + sway, 0.6, 0),
                    euler: SCNVector3(0, 0, 0.15)
                )
            }
        } else {
            limb(SCNVector3(0, hip + 0.02 + bob, 0), SCNVector3(0, hip + 0.06 + bob, 0), radius: 0.17 * fig.limbs, Cloth.leather)
        }
        // Arms swing against the legs, forearms carried a little forward, unless the load needs them.
        let swing = -0.38 * sin(angle)
        for side in [CGFloat(1), -1] {
            let top = SCNVector3(0, shoulder + bob, side * 0.21 * fig.limbs)
            let (elbow, hand) = arm(fig, side: side, top: top, swing: swing * side)
            limb(top, elbow, radius: limbR * 0.9, fig.tunic)
            limb(elbow, hand, radius: limbR * 0.85, fig.tunic)
            ball(hand, radius: limbR * 0.95, Cloth.skin)
        }
        // Head.
        let headRadius = 0.105 * fig.head
        let headCentre = SCNVector3(0.01, shoulder + 0.07 + headRadius + bob, 0)
        ball(headCentre, radius: headRadius, Cloth.skin)
        // Hair over the back of the head: walking away shows hair, walking toward the camera shows a face.
        ball(headCentre + SCNVector3(-0.035, 0.01, 0), radius: headRadius * 0.97, Cloth.hair)
        headwear(fig.headwear, on: headCentre, radius: headRadius)
        carry(fig, shoulder: SCNVector3(0, shoulder + bob, 0), headTop: headCentre.y + headRadius)
    }

    /// Elbow and hand of one arm hanging from the shoulder at `top`.
    private func arm(_ fig: Figure, side: CGFloat, top: SCNVector3, swing: CGFloat) -> (SCNVector3, SCNVector3) {
        let upper: CGFloat = 0.31, fore: CGFloat = 0.30
        switch (fig.load, side > 0) {
        case (.sack, true), (.crate, true), (.barrel, true), (.logs, true):
            // Right elbow out in front, the hand up on the shouldered load.
            return (top + SCNVector3(0.18, -0.10, 0.08), top + SCNVector3(0.08, 0.28, 0.02))
        case (.push, _):
            // Both hands forward at the hips, on the cart's handles.
            return (top + SCNVector3(0.16, -0.24, side * 0.03), top + SCNVector3(0.42, -0.44, side * 0.04))
        case (.yoke, true):
            // Right hand up on the pole over the shoulder.
            return (top + SCNVector3(0.16, -0.06, 0.04), top + SCNVector3(0.10, 0.12, 0.10))
        case (.basket, false):
            // Left elbow out to the side, the hand up steadying the basket on the head.
            return (top + SCNVector3(0.10, 0.04, -0.14), top + SCNVector3(0.06, 0.36, 0.04))
        default:
            let elbow = top + SCNVector3(sin(swing) * upper, -cos(swing) * upper, side * 0.02)
            let forearm = swing + 0.35
            return (elbow, elbow + SCNVector3(sin(forearm) * fore, -cos(forearm) * fore, side * 0.02))
        }
    }

    private func headwear(_ kind: Headwear, on centre: SCNVector3, radius: CGFloat) {
        switch kind {
        case .cap:
            ball(centre + SCNVector3(-0.025, radius * 0.55, 0), radius: radius * 1.05, Cloth.felt, scale: SCNVector3(1, 0.55, 1))
        case .straw:
            add(
                SCNCylinder(radius: radius * 2.1, height: 0.03),
                Finish.paint(Cloth.straw).material(),
                at: centre + SCNVector3(0, radius * 0.55, 0)
            )
            ball(centre + SCNVector3(0, radius * 0.7, 0), radius: radius * 0.9, Cloth.straw, scale: SCNVector3(1, 0.8, 1))
        case .coif:
            ball(centre + SCNVector3(-0.02, radius * 0.15, 0), radius: radius * 1.12, Cloth.linen, scale: SCNVector3(1, 1.05, 1.02))
        case .hood:
            ball(centre + SCNVector3(-0.03, radius * 0.1, 0), radius: radius * 1.18, Cloth.walnut)
        }
    }

    private func carry(_ fig: Figure, shoulder: SCNVector3, headTop: CGFloat) {
        let right = shoulder + SCNVector3(-0.02, 0.12, 0.17)
        switch fig.load {
        case .none, .push:
            break
        case .yoke:
            yoke(shoulder: shoulder)
        case .basket:
            let base = SCNVector3(0.02, headTop + 0.02, 0)
            add(
                SCNCone(topRadius: 0.24, bottomRadius: 0.16, height: 0.2),
                Finish.paint(Cloth.wicker).material(),
                at: base + SCNVector3(0, 0.1, 0)
            )
            ball(base + SCNVector3(0, 0.2, 0), radius: 0.17, Cloth.loaf, scale: SCNVector3(1, 0.4, 1))
        case .sack:
            let sack = ball(right + SCNVector3(-0.10, 0.02, 0.04), radius: 0.2, Cloth.burlap, scale: SCNVector3(1.5, 0.8, 0.85))
            sack.eulerAngles = SCNVector3(0, 0, -0.35)
        case .crate:
            block(right + SCNVector3(-0.24, -0.02, -0.08), right + SCNVector3(0.14, 0.3, 0.26), .paint(Cloth.deal))
        case .barrel:
            add(
                SCNCylinder(radius: 0.2, height: 0.52),
                Finish.paint(Cloth.stave).material(),
                at: right + SCNVector3(-0.04, 0.14, 0.06),
                euler: SCNVector3(0, 0, CGFloat.pi / 2)
            )
            for hoop in [CGFloat(-0.17), 0.17] {
                add(
                    SCNCylinder(radius: 0.205, height: 0.04),
                    Finish.paint(Trade.iron).material(),
                    at: right + SCNVector3(hoop - 0.04, 0.14, 0.06),
                    euler: SCNVector3(0, 0, CGFloat.pi / 2)
                )
            }
        case .logs:
            let logs = [SCNVector3(-0.05, 0.1, -0.05), SCNVector3(-0.05, 0.1, 0.11), SCNVector3(-0.05, 0.23, 0.03)]
            for (index, offset) in logs.enumerated() {
                add(
                    SCNCylinder(radius: 0.075, height: 1.1 - CGFloat(index) * 0.12),
                    Finish.paint(Cloth.bark).material(),
                    at: right + offset,
                    euler: SCNVector3(0, 0, CGFloat.pi / 2 - 0.12)
                )
            }
        }
    }

    /// A pole across the shoulders with a basket of loaves hanging from each end.
    private func yoke(shoulder: SCNVector3) {
        let pole = SCNVector3(0.02, shoulder.y + 0.1, 0)
        add(
            SCNCylinder(radius: 0.03, height: 1.25),
            Finish.paint(Cloth.bark).material(),
            at: pole,
            euler: SCNVector3(CGFloat.pi / 2, 0, 0)
        )
        for side in [CGFloat(-1), 1] {
            let end = pole + SCNVector3(0, 0, side * 0.58)
            limb(end, end + SCNVector3(0, -0.5, 0), radius: 0.01, Cloth.straw)
            add(
                SCNCone(topRadius: 0.2, bottomRadius: 0.14, height: 0.24),
                Finish.paint(Cloth.wicker).material(),
                at: end + SCNVector3(0, -0.62, 0)
            )
            ball(end + SCNVector3(0, -0.5, 0), radius: 0.15, Cloth.loaf, scale: SCNVector3(1, 0.4, 1))
        }
    }

    /// Builds `body` (facing +x, standing on the origin) turned to `facing` and scaled, standing on `ground`.
    func turned(_ facing: WalkerFacing, at ground: SCNVector3, scale: CGFloat = 1, _ body: (Builder) -> Void) {
        let local = Builder()
        body(local)
        local.root.position = ground
        local.root.eulerAngles = SCNVector3(0, facing.yaw, 0)
        local.root.scale = SCNVector3(scale, scale, scale)
        root.addChildNode(local.root)
    }
}
