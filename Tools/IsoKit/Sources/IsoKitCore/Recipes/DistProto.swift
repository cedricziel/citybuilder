// Scratch prototypes for visible-distribution: handcarts and market porters.
import SceneKit

extension Builder {
    /// A wheel of `radius` at `centre`, its axle along z, spokes turned by `turn`.
    func wheel(_ centre: SCNVector3, radius: CGFloat, turn: CGFloat) {
        add(
            SCNTube(innerRadius: radius - 0.04, outerRadius: radius, height: 0.06),
            Finish.paint(Cloth.stave).material(),
            at: centre,
            euler: SCNVector3(CGFloat.pi / 2, 0, 0)
        )
        for spoke in 0 ..< 3 {
            let angle = turn + CGFloat(spoke) * .pi / 3
            add(
                SCNBox(width: 0.035, height: radius * 2 - 0.06, length: 0.035, chamferRadius: 0),
                Finish.paint(Cloth.deal).material(),
                at: centre,
                euler: SCNVector3(0, 0, angle)
            )
        }
        add(
            SCNCylinder(radius: 0.05, height: 0.1),
            Finish.paint(Cloth.bark).material(),
            at: centre,
            euler: SCNVector3(CGFloat.pi / 2, 0, 0)
        )
    }

    /// Sacks and a crate piled in a load bay between `lo` and `hi`.
    func cartLoad(_ lo: SCNVector3, _ hi: SCNVector3) {
        let midZ = (lo.z + hi.z) / 2, span = hi.x - lo.x
        ball(SCNVector3(lo.x + span * 0.3, hi.y + 0.1, midZ - 0.12), radius: 0.2, Cloth.burlap, scale: SCNVector3(1.3, 0.75, 0.9))
        ball(SCNVector3(lo.x + span * 0.3, hi.y + 0.1, midZ + 0.14), radius: 0.2, Cloth.burlap, scale: SCNVector3(1.3, 0.75, 0.9))
        block(SCNVector3(lo.x + span * 0.55, hi.y, midZ - 0.2), SCNVector3(lo.x + span * 0.9, hi.y + 0.32, midZ + 0.18), .paint(Cloth.deal))
    }

    /// A one-wheeled barrow ahead of a walker facing +x.
    func wheelbarrow(phase: CGFloat) {
        let lo = SCNVector3(0.62, 0.42, -0.26), hi = SCNVector3(1.42, 0.66, 0.26)
        block(lo, hi, .paint(Cloth.deal))
        for side in [CGFloat(-1), 1] {
            limb(SCNVector3(0.42, 0.62, side * 0.2), SCNVector3(1.6, 0.42, side * 0.12), radius: 0.03, Cloth.bark)
            limb(SCNVector3(0.75, 0.42, side * 0.2), SCNVector3(0.75, 0.02, side * 0.2), radius: 0.025, Cloth.bark)
        }
        wheel(SCNVector3(1.55, 0.22, 0), radius: 0.22, turn: -phase * 2 * .pi)
        cartLoad(lo, hi)
    }

    /// A two-wheeled handcart ahead of a walker facing +x, pushed by its two handles.
    func handcart(phase: CGFloat) {
        let lo = SCNVector3(0.62, 0.5, -0.36), hi = SCNVector3(1.72, 0.74, 0.36)
        block(lo, hi, .paint(Cloth.deal))
        for side in [CGFloat(-1), 1] {
            block(SCNVector3(lo.x, hi.y, side * 0.36 - 0.03), SCNVector3(hi.x, hi.y + 0.22, side * 0.36 + 0.03), .paint(Cloth.stave))
            limb(SCNVector3(0.42, 0.62, side * 0.22), SCNVector3(lo.x + 0.05, 0.66, side * 0.3), radius: 0.03, Cloth.bark)
            wheel(SCNVector3(1.15, 0.36, side * 0.44), radius: 0.36, turn: -phase * 1.3 * .pi)
        }
        cartLoad(lo, hi)
    }
}

extension Recipes {
    static let cartCell = SpriteCell(footprint: 1, heightPx: 48, widthPx: 64)
    static let cartGround = ground(lift: 14, left: 0)

    static let distProtos: [Recipe] = {
        func pusher(_ tunic: NSColor) -> Figure {
            var figure = storybook
            figure.tunic = tunic
            figure.hose = Cloth.walnut
            figure.headwear = .straw
            figure.load = .push
            return figure
        }
        var porter = storybook
        porter.tunic = Cloth.madder
        porter.skirt = Cloth.woad
        porter.apron = Cloth.linen
        porter.headwear = .coif
        porter.load = .basket
        var yoke = storybook
        yoke.tunic = Cloth.weld
        yoke.hose = Cloth.walnut
        yoke.headwear = .cap
        yoke.load = .yoke
        let barrowFig = pusher(Cloth.fustian), cartFig = pusher(Cloth.woad)
        return facingRecipes(
            "proto-barrow",
            entry: "walker",
            cell: cartCell,
            frames: gaitFrames,
            scale: storybook.scale,
            ground: cartGround
        ) {
            $0.figure(barrowFig, phase: $1)
            $0.wheelbarrow(phase: $1)
        } + facingRecipes(
            "proto-handcart",
            entry: "walker",
            cell: cartCell,
            frames: gaitFrames,
            scale: storybook.scale,
            ground: cartGround
        ) {
            $0.figure(cartFig, phase: $1)
            $0.handcart(phase: $1)
        } + facingRecipes("proto-porter-basket", entry: "walker", cell: walkerCell, frames: gaitFrames, scale: storybook.scale) {
            $0.figure(porter, phase: $1)
        } + facingRecipes("proto-porter-yoke", entry: "walker", cell: walkerCell, frames: gaitFrames, scale: storybook.scale) {
            $0.figure(yoke, phase: $1)
        }
    }()
}
