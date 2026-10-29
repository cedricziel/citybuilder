// isokit: the handcart (visible-distribution milestone 3). One person pushes a two-wheeled cart with a generic
// load, in 4 facings x 8 gait frames: `handcart-<facing>-<frame>`.
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
            add(
                SCNBox(width: 0.035, height: radius * 2 - 0.06, length: 0.035, chamferRadius: 0),
                Finish.paint(Cloth.deal).material(),
                at: centre,
                euler: SCNVector3(0, 0, turn + CGFloat(spoke) * .pi / 3)
            )
        }
        add(
            SCNCylinder(radius: 0.05, height: 0.1),
            Finish.paint(Cloth.bark).material(),
            at: centre,
            euler: SCNVector3(CGFloat.pi / 2, 0, 0)
        )
    }

    /// Two sacks and a crate in the load bay between `lo` and `hi`.
    func cartLoad(_ lo: SCNVector3, _ hi: SCNVector3) {
        let midZ = (lo.z + hi.z) / 2, span = hi.x - lo.x
        for offset in [CGFloat(-0.12), 0.14] {
            ball(SCNVector3(lo.x + span * 0.3, hi.y + 0.1, midZ + offset), radius: 0.2, Cloth.burlap, scale: SCNVector3(1.3, 0.75, 0.9))
        }
        block(SCNVector3(lo.x + span * 0.55, hi.y, midZ - 0.2), SCNVector3(lo.x + span * 0.9, hi.y + 0.32, midZ + 0.18), .paint(Cloth.deal))
    }

    /// A two-wheeled handcart ahead of a walker facing +x, pushed by its two handles; the wheels turn with
    /// the gait `phase`.
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
    /// 64 x 48 pt: the pusher and the cart ahead of them, in any facing, with the shadow.
    static let cartCell = SpriteCell(footprint: 1, heightPx: 48, widthPx: 64)
    /// The pusher stands 14 pt above the cell's bottom edge, centred. The renderer anchors handcarts there:
    /// `SpriteAtlas.handcartAnchor`, (32/64, 14/48).
    static let cartGround = ground(lift: 14, left: 0)

    static let handcarts: [Recipe] = {
        var pusher = storybook
        pusher.tunic = Cloth.woad
        pusher.hose = Cloth.walnut
        pusher.headwear = .straw
        pusher.load = .push
        return facingRecipes(
            "handcart", entry: "handcart", cell: cartCell, frames: gaitFrames, scale: storybook.scale, ground: cartGround
        ) {
            $0.figure(pusher, phase: $1)
            $0.handcart(phase: $1)
        }
    }()
}
