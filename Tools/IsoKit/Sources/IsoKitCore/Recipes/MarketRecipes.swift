// isokit: the marketplace, a market hub smaller than the town center (visible-distribution M2b). An open
// hall on posts over two stalls, open on every side so porters come and go from any road. Its top follows
// the culture: a half-timbered upper floor, a wide-eaved slate hip, a low tile hip on piers, or a parapet
// roof with domes. The culture looks are finished sprites; construction uses the shared frames.
import AppKit
import SceneKit

enum Market {
    static let wicker = NSColor(red: 0.56, green: 0.42, blue: 0.24, alpha: 1)
    static let indigo = NSColor(red: 0.22, green: 0.26, blue: 0.44, alpha: 1)
    static let cream = NSColor(red: 0.90, green: 0.86, blue: 0.74, alpha: 1)
    static let sand = NSColor(red: 0.76, green: 0.66, blue: 0.48, alpha: 1)
    static let produce = [
        NSColor(red: 0.72, green: 0.22, blue: 0.16, alpha: 1),
        NSColor(red: 0.42, green: 0.56, blue: 0.24, alpha: 1),
        NSColor(red: 0.86, green: 0.62, blue: 0.22, alpha: 1)
    ]

    /// The hall's footprint: posts stand on its edges, the roof sits on top.
    static let lo = SCNVector3(1.0, 0, 1.0)
    static let hi = SCNVector3(6.8, 0, 6.0)
}

extension Recipes {
    static let market: [Recipe] = [
        Recipe(id: "building-marketplace", cell: SpriteCell(footprint: 2, heightPx: 144)) { kit, _ in
            marketHall(kit, paving: .cobbles, posts: .timber, awnings: [Palette.shutterRed, Palette.sailcloth])
            marketTopNorth(kit)
        },
        marketLook("east-asian", height: 128) { kit in
            marketHall(kit, paving: .paint(Civic.gravel), posts: .paint(Civic.lacquer), awnings: [Market.indigo, Market.cream])
            kit.hipRoof(RoofSpec(
                lo: SCNVector3(Market.lo.x, 2.9, Market.lo.z),
                hi: Market.hi,
                pitchDegrees: 28,
                overhang: 1.0,
                finish: .slate
            ))
        },
        marketLook("mediterranean", height: 128) { kit in
            marketHall(kit, paving: .paint(Civic.travertine), posts: .plasterPale, awnings: [Civic.ochre, Market.cream])
            let lo = Market.lo - SCNVector3(0.2, 0, 0.2), hi = Market.hi + SCNVector3(0.2, 0, 0.2)
            kit.block(SCNVector3(lo.x, 2.6, lo.z), SCNVector3(hi.x, 3.1, hi.z), .plasterPale)
            kit.hipRoof(RoofSpec(lo: SCNVector3(lo.x, 3.1, lo.z), hi: hi, pitchDegrees: 22, finish: .tile))
        },
        marketLook("middle-eastern", height: 128) { kit in
            marketHall(kit, paving: .paint(Market.sand), posts: .ashlar, awnings: [Trade.blueTile, Civic.ochre])
            let lo = Market.lo - SCNVector3(0.2, 0, 0.2), hi = Market.hi + SCNVector3(0.2, 0, 0.2)
            kit.parapetBlock(SCNVector3(lo.x, 2.6, lo.z), SCNVector3(hi.x, 3.2, hi.z))
            for x in [CGFloat(2.6), 5.2] {
                kit.ball(SCNVector3(x, 3.2, 3.5), radius: 1.0, Trade.blueTile, scale: SCNVector3(1, 0.8, 1))
            }
        }
    ]

    /// A culture look of the marketplace: `building-marketplace-<look>`, a finished sprite only.
    static func marketLook(_ look: String, height: Int, _ body: @escaping (Builder) -> Void) -> Recipe {
        Recipe(id: "building-marketplace-\(look)", cell: SpriteCell(footprint: 2, heightPx: height), constructionFrames: 0) { kit, _ in
            body(kit)
        }
    }

    /// The paved plot, the posts on a low stone base, two stalls under the roof and baskets in the yard.
    static func marketHall(_ kit: Builder, paving: Finish, posts: Finish, awnings: [NSColor]) {
        let lo = Market.lo, hi = Market.hi
        kit.ground(SCNVector3(0.2, 0, 0.2), SCNVector3(7.8, 0, 7.8), paving)
        kit.block(SCNVector3(lo.x - 0.1, 0, lo.z - 0.1), SCNVector3(hi.x + 0.1, 0.2, hi.z + 0.1), .ashlar)
        for x in stride(from: lo.x, through: hi.x, by: (hi.x - lo.x) / 3) {
            for depth in [lo.z, hi.z] {
                kit.block(SCNVector3(x - 0.15, 0.2, depth - 0.15), SCNVector3(x + 0.15, 2.6, depth + 0.15), posts)
            }
        }
        let middle = (lo.z + hi.z) / 2
        kit.block(SCNVector3(hi.x - 0.15, 0.2, middle - 0.15), SCNVector3(hi.x + 0.15, 2.6, middle + 0.15), posts)
        kit.marketStall(at: SCNVector3(2.6, 0.2, 3.6), cloth: awnings[0], seed: 0)
        kit.marketStall(at: SCNVector3(5.2, 0.2, 3.6), cloth: awnings[1], seed: 1)
        kit.basket(at: SCNVector3(2.2, 0, 7.0), Market.produce[0])
        kit.basket(at: SCNVector3(2.8, 0, 7.2), Market.produce[1])
        kit.crate(at: SCNVector3(7.3, 0, 6.8))
    }

    /// The northern top: a half-timbered upper floor with two windows under a steep tile gable.
    static func marketTopNorth(_ kit: Builder) {
        let lo = Market.lo - SCNVector3(0.2, 0, 0.2), hi = Market.hi + SCNVector3(0.2, 0, 0.2)
        kit.block(SCNVector3(lo.x, 2.6, lo.z), SCNVector3(hi.x, 4.6, hi.z), .plaster)
        kit.timberFrame(Face.south(wallZ: hi.z), span: lo.x ... hi.x, base: 2.6, height: 2.0, posts: 4)
        kit.timberFrame(Face.east(wallX: hi.x), span: lo.z ... hi.z, base: 2.6, height: 2.0, posts: 3)
        kit.window(Face.south(wallZ: hi.z), along: 2.6, y: 3.6)
        kit.window(Face.south(wallZ: hi.z), along: 5.2, y: 3.6)
        kit.gableRoof(RoofSpec(lo: SCNVector3(lo.x, 4.6, lo.z), hi: hi, pitchDegrees: 48, finish: .tile, ridgeAlongX: true))
    }
}

extension Builder {
    func basket(at base: SCNVector3, _ colour: NSColor) {
        add(SCNCylinder(radius: 0.26, height: 0.32), Finish.paint(Market.wicker).material(), at: base + SCNVector3(0, 0.16, 0))
        ball(base + SCNVector3(0, 0.32, 0), radius: 0.22, colour, scale: SCNVector3(1, 0.5, 1))
    }

    /// A stall under a `cloth` awning with produce on the counter and a basket at its corner.
    func marketStall(at base: SCNVector3, cloth: NSColor, seed: Int) {
        stall(at: base, cloth: cloth)
        for index in 0 ..< 2 {
            let colour = Market.produce[(seed + index) % Market.produce.count]
            let spot = base + SCNVector3(-0.35 + CGFloat(index) * 0.7, 0.95, 0.1)
            ball(spot, radius: 0.18, colour, scale: SCNVector3(1.3, 0.6, 1))
        }
        basket(at: base + SCNVector3(0.9, 0, 0.7), Market.produce[seed % Market.produce.count])
    }
}
