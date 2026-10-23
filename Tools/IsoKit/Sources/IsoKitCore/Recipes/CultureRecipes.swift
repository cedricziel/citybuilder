// isokit: the culture looks of the house (three tiers) and the town center, for the East Asian,
// Mediterranean and Middle Eastern cultures. Construction uses the shared frames, so these are
// finished sprites only; the town centers keep two operational frames like the shared one.
import AppKit
import SceneKit

enum Looks {
    static let blueShutter = NSColor(red: 0.22, green: 0.38, blue: 0.54, alpha: 1)
    static let lattice = NSColor(red: 0.30, green: 0.19, blue: 0.11, alpha: 1)
}

extension Recipes {
    static let culture: [Recipe] = [
        house("east-asian", tier: 1, height: 112, houseEastAsian),
        house("east-asian", tier: 2, height: 144, houseEastAsian2),
        house("east-asian", tier: 3, height: 176, houseEastAsian3),
        house("mediterranean", tier: 1, height: 112, houseMediterranean),
        house("mediterranean", tier: 2, height: 144, houseMediterranean2),
        house("mediterranean", tier: 3, height: 176, houseMediterranean3),
        house("middle-eastern", tier: 1, height: 112, houseMiddleEastern),
        house("middle-eastern", tier: 2, height: 144, houseMiddleEastern2),
        house("middle-eastern", tier: 3, height: 176, houseMiddleEastern3),
        townCenterLook("east-asian", height: 224, townCenterEastAsian),
        townCenterLook("mediterranean", height: 224, townCenterMediterranean),
        townCenterLook("middle-eastern", height: 224, townCenterMiddleEastern)
    ]

    /// A finished house look: `building-house[-tierN]-<look>`, owned by the `building-house-<look>` brief.
    static func house(_ look: String, tier: Int, height: Int, _ body: @escaping (Builder) -> Void) -> Recipe {
        Recipe(
            id: tier == 1 ? "building-house-\(look)" : "building-house-tier\(tier)-\(look)",
            entry: "building-house-\(look)",
            cell: SpriteCell(footprint: 2, heightPx: height),
            constructionFrames: 0
        ) { kit, _ in body(kit) }
    }

    static func townCenterLook(_ look: String, height: Int, _ body: @escaping (Builder) -> Void) -> Recipe {
        Recipe(
            id: "building-town-center-\(look)",
            cell: SpriteCell(footprint: 3, heightPx: height),
            constructionFrames: 0,
            operationalFrames: 2
        ) { kit, _ in
            kit.ground(SCNVector3(0.2, 0, 0.2), SCNVector3(11.8, 0, 11.8), .cobbles)
            body(kit)
        }
    }

    // MARK: East Asian

    /// A pale plaster hall between dark posts on a stone base, under a wide-eaved slate hip roof.
    static func houseEastAsian(_ kit: Builder) {
        kit.hallEast(SCNVector3(1.4, 0, 1.4), SCNVector3(6.6, 2.7, 6.0), plinth: 0.45)
        kit.hipRoof(RoofSpec(lo: SCNVector3(1.4, 3.0, 1.4), hi: SCNVector3(6.6, 0, 6.0), pitchDegrees: 30, overhang: 0.9, finish: .slate))
        kit.chimney(x: 5.2, depth: 4.6, from: 2.7, to: 4.7, finish: .brick)
        kit.block(SCNVector3(2.6, 0, 6.9), SCNVector3(3.4, 0.5, 7.5), .thatch)
    }

    /// Two storeys: a pent roof skirts the ground floor, and a flared hip roof crowns the upper one.
    static func houseEastAsian2(_ kit: Builder) {
        kit.hallEast(SCNVector3(1.0, 0, 1.2), SCNVector3(7.0, 2.6, 6.4), plinth: 0.45)
        kit.pent(SCNVector3(1.0, 2.6, 1.2), SCNVector3(7.0, 0, 6.4))
        kit.hallEast(SCNVector3(1.5, 2.8, 1.6), SCNVector3(6.5, 5.0, 6.0), plinth: 0)
        kit.hipRoof(RoofSpec(lo: SCNVector3(1.5, 5.3, 1.6), hi: SCNVector3(6.5, 0, 6.0), pitchDegrees: 30, overhang: 0.9, finish: .slate))
        kit.chimney(x: 5.1, depth: 4.6, from: 5.0, to: 7.0, finish: .brick)
    }

    /// Three storeys over a dark tiled plinth wall, two pent roofs, red posts and a flared crown roof.
    static func houseEastAsian3(_ kit: Builder) {
        kit.block(SCNVector3(0.8, 0, 0.8), SCNVector3(7.2, 1.0, 7.0), .slate)
        kit.hallEast(SCNVector3(1.0, 1.0, 1.0), SCNVector3(7.0, 3.4, 6.8), plinth: 0, posts: .paint(Civic.lacquer))
        kit.pent(SCNVector3(1.0, 3.4, 1.0), SCNVector3(7.0, 0, 6.8))
        kit.hallEast(SCNVector3(1.4, 3.6, 1.4), SCNVector3(6.6, 5.6, 6.4), plinth: 0, posts: .paint(Civic.lacquer))
        kit.pent(SCNVector3(1.4, 5.6, 1.4), SCNVector3(6.6, 0, 6.4))
        kit.hallEast(SCNVector3(1.9, 5.8, 1.9), SCNVector3(6.1, 7.6, 5.9), plinth: 0)
        kit.hipRoof(RoofSpec(lo: SCNVector3(1.9, 7.9, 1.9), hi: SCNVector3(6.1, 0, 5.9), pitchDegrees: 30, overhang: 0.9, finish: .slate))
        kit.chimney(x: 4.9, depth: 4.6, from: 7.6, to: 9.4, finish: .brick)
    }

    // MARK: Mediterranean

    /// A whitewashed cottage under a low tile hip roof, blue shutters and door, a chimney and amphorae.
    static func houseMediterranean(_ kit: Builder) {
        kit.hall(SCNVector3(1.2, 0, 1.4), SCNVector3(6.6, 0, 5.8), walls: .plasterPale, roof: .tile, wallHeight: 2.8, pitch: 24, hip: true)
        kit.shuttered(Face.south(wallZ: 5.8), at: [2.4, 5.4], y: 1.7)
        kit.onFace(
            Face.south(wallZ: 5.8),
            FaceRect(along: 3.9, y: 1.25, width: 1.0, height: 2.0),
            depth: 0.06,
            finish: .paint(Looks.blueShutter)
        )
        kit.shuttered(Face.east(wallX: 6.6), at: [3.6], y: 1.7)
        kit.chimney(x: 5.2, depth: 4.4, from: 2.8, to: 4.72, finish: .plasterPale, cap: .tile)
        kit.amphorae(at: SCNVector3(4.6, 0, 7.0))
    }

    /// Two whitewashed storeys over an arcaded loggia, under a low tile hip roof.
    static func houseMediterranean2(_ kit: Builder) {
        kit.hall(SCNVector3(1.0, 0, 1.2), SCNVector3(7.0, 0, 6.2), walls: .plasterPale, roof: .tile, wallHeight: 5.0, pitch: 24, hip: true)
        kit.arcade(Face.south(wallZ: 6.2), from: 1.4, to: 6.6, base: 0.25)
        kit.shuttered(Face.south(wallZ: 6.2), at: [2.2, 4.0, 5.8], y: 4.0)
        kit.shuttered(Face.east(wallX: 7.0), at: [2.4, 4.8], y: 4.0)
        kit.shuttered(Face.east(wallX: 7.0), at: [3.6], y: 1.6)
        kit.chimney(x: 5.6, depth: 4.6, from: 5.0, to: 6.9, finish: .plasterPale, cap: .tile)
    }

    /// Three storeys on a stone ground floor, a balcony, and a belvedere tower with an open loggia.
    static func houseMediterranean3(_ kit: Builder) {
        kit.block(SCNVector3(0.9, 0, 1.0), SCNVector3(7.1, 2.6, 6.6), .ashlar)
        kit.hall(
            SCNVector3(0.9, 2.6, 1.0),
            SCNVector3(7.1, 0, 6.6),
            walls: .plasterPale,
            roof: .tile,
            wallHeight: 4.2,
            pitch: 24,
            hip: true,
            plinth: false
        )
        kit.archDoor(Face.south(wallZ: 6.6), along: 4.0, width: 1.4, height: 2.2, finish: .planks)
        kit.shuttered(Face.south(wallZ: 6.6), at: [2.0, 4.0, 6.0], y: 3.8)
        kit.shuttered(Face.south(wallZ: 6.6), at: [2.0, 4.0, 6.0], y: 5.8)
        kit.shuttered(Face.east(wallX: 7.1), at: [2.4, 5.0], y: 3.8)
        kit.block(SCNVector3(2.6, 2.9, 6.6), SCNVector3(5.4, 3.0, 7.4), .ashlar)
        kit.block(SCNVector3(2.6, 3.0, 7.32), SCNVector3(5.4, 3.8, 7.4), .paint(Trade.iron))
        kit.chimney(x: 5.8, depth: 5.0, from: 6.8, to: 8.4, finish: .plasterPale, cap: .tile)
        kit.block(SCNVector3(1.4, 6.8, 1.4), SCNVector3(3.6, 8.6, 3.6), .plasterPale)
        kit.arcade(Face.south(wallZ: 3.6), from: 1.6, to: 3.4, base: 6.9)
        kit.arcade(Face.east(wallX: 3.6), from: 1.6, to: 3.4, base: 6.9)
        kit.hipRoof(RoofSpec(lo: SCNVector3(1.4, 8.6, 1.4), hi: SCNVector3(3.6, 0, 3.6), pitchDegrees: 24, overhang: 0.3, finish: .tile))
    }

    // MARK: Middle Eastern

    /// A sandstone cottage behind a parapet, small arched windows, a blue-framed door under an awning, and a palm.
    static func houseMiddleEastern(_ kit: Builder) {
        kit.parapetBlock(SCNVector3(1.4, 0, 1.4), SCNVector3(6.0, 3.0, 5.6))
        kit.chimney(x: 5.1, depth: 4.7, from: 3.0, to: 4.1, finish: .ashlar)
        kit.blueArch(Face.south(wallZ: 5.6), along: 3.6, width: 1.0, height: 2.0)
        for along in [2.2, 5.0] as [CGFloat] {
            kit.archDoor(Face.south(wallZ: 5.6), along: along, width: 0.5, height: 0.9, base: 1.3, finish: .glass)
        }
        kit.archDoor(Face.east(wallX: 6.0), along: 3.5, width: 0.5, height: 0.9, base: 1.3, finish: .glass)
        kit.awning(at: SCNVector3(3.6, 2.4, 6.0), width: 1.8)
        kit.crate(at: SCNVector3(5.2, 0, 6.4))
        kit.palm(at: SCNVector3(6.8, 0, 6.8))
    }

    /// Two storeys with a projecting lattice bay and a rooftop room behind its own parapet.
    static func houseMiddleEastern2(_ kit: Builder) {
        kit.parapetBlock(SCNVector3(1.0, 0, 1.2), SCNVector3(6.8, 5.2, 6.4))
        kit.chimney(x: 5.9, depth: 5.5, from: 5.2, to: 6.3, finish: .ashlar)
        kit.blueArch(Face.south(wallZ: 6.4), along: 2.4, width: 1.0, height: 2.0)
        kit.latticeBay(Face.south(wallZ: 6.4), along: 4.8, base: 2.8)
        kit.archDoor(Face.east(wallX: 6.8), along: 3.8, width: 0.5, height: 0.9, base: 3.4, finish: .glass)
        kit.parapetBlock(SCNVector3(1.4, 5.2, 1.6), SCNVector3(3.8, 7.0, 3.8))
        kit.awning(at: SCNVector3(4.8, 2.3, 6.8), width: 1.6)
    }

    /// Three storeys with two lattice bays and a slotted wind tower on the roof.
    static func houseMiddleEastern3(_ kit: Builder) {
        kit.parapetBlock(SCNVector3(0.9, 0, 1.0), SCNVector3(7.0, 7.4, 6.6))
        kit.chimney(x: 6.1, depth: 5.7, from: 7.4, to: 8.5, finish: .ashlar)
        kit.blueArch(Face.south(wallZ: 6.6), along: 4.0, width: 1.2, height: 2.2)
        kit.latticeBay(Face.south(wallZ: 6.6), along: 2.2, base: 3.0)
        kit.latticeBay(Face.south(wallZ: 6.6), along: 5.8, base: 3.0)
        kit.latticeBay(Face.east(wallX: 7.0), along: 3.8, base: 5.2)
        for base in [1.3, 3.4] as [CGFloat] {
            kit.archDoor(Face.east(wallX: 7.0), along: 2.2, width: 0.5, height: 0.9, base: base, finish: .glass)
        }
        kit.block(SCNVector3(1.6, 7.4, 1.6), SCNVector3(3.0, 10.2, 3.0), .ashlar)
        for along in [1.95, 2.65] as [CGFloat] {
            kit.onFace(
                Face.south(wallZ: 3.0),
                FaceRect(along: along, y: 9.2, width: 0.22, height: 1.4),
                depth: 0.03,
                finish: .paint(Crops.opening)
            )
            kit.onFace(
                Face.east(wallX: 3.0),
                FaceRect(along: along, y: 9.2, width: 0.22, height: 1.4),
                depth: 0.03,
                finish: .paint(Crops.opening)
            )
        }
    }

    // MARK: town centers

    /// A three-storey pagoda on a stone platform, red posts, flared slate roofs shrinking to a finial,
    /// and stone lanterns at the front corners.
    static func townCenterEastAsian(_ kit: Builder) {
        kit.block(SCNVector3(2.0, 0, 2.0), SCNVector3(10.0, 0.8, 10.0), .ashlar)
        var half: CGFloat = 3.0, base: CGFloat = 0.8
        for _ in 0 ..< 3 {
            let lo = SCNVector3(6 - half, base, 6 - half), hi = SCNVector3(6 + half, base + 2.4, 6 + half)
            kit.hallEast(lo, hi, plinth: 0, posts: .paint(Civic.lacquer))
            kit.hipRoof(RoofSpec(lo: SCNVector3(lo.x, hi.y + 0.3, lo.z), hi: hi, pitchDegrees: 28, overhang: 1.0, finish: .slate))
            base += 3.4
            half -= 0.7
        }
        kit.add(SCNCylinder(radius: 0.12, height: 2.0), Finish.paint(Civic.bronze).material(), at: SCNVector3(6, base + 0.4, 6))
        for corner in [SCNVector3(10.8, 0, 3.0), SCNVector3(3.0, 0, 10.8), SCNVector3(10.8, 0, 10.8)] {
            kit.block(corner + SCNVector3(-0.25, 0, -0.25), corner + SCNVector3(0.25, 1.2, 0.25), .ashlar)
            kit.block(corner + SCNVector3(-0.4, 1.2, -0.4), corner + SCNVector3(0.4, 1.4, 0.4), .ashlar)
        }
    }

    /// A whitewashed hall under a low tile hip roof beside a square campanile with an open belfry.
    static func townCenterMediterranean(_ kit: Builder) {
        kit.hall(SCNVector3(1.4, 0, 3.6), SCNVector3(8.4, 0, 9.6), walls: .plasterPale, roof: .tile, wallHeight: 4.0, pitch: 24, hip: true)
        kit.archDoor(Face.south(wallZ: 9.6), along: 4.9, width: 1.6, height: 2.6, finish: .planks)
        kit.shuttered(Face.south(wallZ: 9.6), at: [2.6, 7.2], y: 2.2)
        kit.shuttered(Face.east(wallX: 8.4), at: [5.0, 8.2], y: 2.2)
        kit.block(SCNVector3(8.6, 0, 1.4), SCNVector3(10.8, 0.8, 3.6), .ashlar)
        kit.block(SCNVector3(8.7, 0.8, 1.5), SCNVector3(10.7, 8.6, 3.5), .plasterPale)
        kit.arcade(Face.south(wallZ: 3.5), from: 8.9, to: 10.5, base: 7.0)
        kit.arcade(Face.east(wallX: 10.7), from: 1.7, to: 3.3, base: 7.0)
        kit.block(SCNVector3(8.6, 9.6, 1.4), SCNVector3(10.8, 9.8, 3.6), .ashlar)
        kit.add(SCNPyramid(width: 2.4, height: 1.4, length: 2.4), Finish.tile.material(), at: SCNVector3(9.7, 9.8, 2.5))
    }

    /// A sandstone hall behind a parapet under a big blue dome on a drum, an iwan portal framed in blue
    /// tile, and a slender minaret with a balcony and a small dome.
    static func townCenterMiddleEastern(_ kit: Builder) {
        kit.parapetBlock(SCNVector3(1.4, 0, 2.6), SCNVector3(8.8, 4.6, 9.6))
        kit.onFace(
            Face.south(wallZ: 9.6),
            FaceRect(along: 5.1, y: 2.4, width: 3.4, height: 4.4),
            depth: 0.04,
            finish: .paint(Trade.blueTile)
        )
        kit.archDoor(Face.south(wallZ: 9.66), along: 5.1, width: 2.4, height: 3.8, finish: .paint(Crops.opening))
        kit.add(SCNCylinder(radius: 2.0, height: 1.2), Finish.ashlar.material(), at: SCNVector3(5.1, 5.6, 6.1))
        kit.add(SCNSphere(radius: 2.0), Finish.paint(Trade.blueTile).material(), at: SCNVector3(5.1, 6.2, 6.1))
        kit.add(SCNCylinder(radius: 0.5, height: 9.0), Finish.ashlar.material(), at: SCNVector3(10.2, 4.5, 2.4))
        kit.add(SCNCylinder(radius: 0.8, height: 0.25), Finish.ashlar.material(), at: SCNVector3(10.2, 7.6, 2.4))
        kit.add(SCNSphere(radius: 0.5), Finish.paint(Trade.blueTile).material(), at: SCNVector3(10.2, 9.0, 2.4))
        kit.palm(at: SCNVector3(10.4, 0, 10.0))
    }
}

// MARK: culture parts

extension Builder {
    /// Pale plaster walls between dark (or red) posts on an optional stone base; `hi.y` is the wall top.
    func hallEast(_ lo: SCNVector3, _ hi: SCNVector3, plinth: CGFloat, posts: Finish = .timber) {
        if plinth > 0 {
            block(SCNVector3(lo.x - 0.2, lo.y, lo.z - 0.2), SCNVector3(hi.x + 0.2, lo.y + plinth, hi.z + 0.2), .ashlar)
        }
        let base = lo.y + plinth
        block(SCNVector3(lo.x, base, lo.z), SCNVector3(hi.x, hi.y, hi.z), .plasterPale)
        for along in stride(from: lo.x, through: hi.x, by: (hi.x - lo.x) / 4) {
            block(SCNVector3(along - 0.1, base, hi.z), SCNVector3(along + 0.1, hi.y, hi.z + 0.1), posts)
        }
        for along in stride(from: lo.z, through: hi.z, by: (hi.z - lo.z) / 3) {
            block(SCNVector3(hi.x, base, along - 0.1), SCNVector3(hi.x + 0.1, hi.y, along + 0.1), posts)
        }
        window(Face.south(wallZ: hi.z + 0.05), along: lo.x + (hi.x - lo.x) * 0.375, y: base + 1.3)
        onFace(
            Face.south(wallZ: hi.z + 0.05),
            FaceRect(along: lo.x + (hi.x - lo.x) * 0.625, y: base + 1.0, width: 1.0, height: 1.9),
            depth: 0.06,
            finish: .planks
        )
    }

    /// A pent roof skirting the two visible sides of a storey, from `lo.y` down and out; the two slabs
    /// meet at the front corner and stop at the back corners.
    func pent(_ lo: SCNVector3, _ hi: SCNVector3) {
        let width = hi.x - lo.x + 0.9, depth = hi.z - lo.z + 0.9
        add(
            SCNBox(width: width, height: 0.12, length: 1.1, chamferRadius: 0),
            Finish.slate.material(repeatU: width / 2, repeatV: 0.5, rotated: true),
            at: SCNVector3(lo.x + width / 2, lo.y - 0.15, hi.z + 0.45),
            euler: SCNVector3(0.38, 0, 0)
        )
        add(
            SCNBox(width: 1.1, height: 0.12, length: depth, chamferRadius: 0),
            Finish.slate.material(repeatU: 0.5, repeatV: depth / 2),
            at: SCNVector3(hi.x + 0.45, lo.y - 0.15, lo.z + depth / 2),
            euler: SCNVector3(0, 0, -0.38)
        )
    }

    /// A shuttered window per entry of `at` on a face.
    func shuttered(_ face: Face, at alongs: [CGFloat], y: CGFloat) {
        for along in alongs {
            window(face, along: along, y: y, shutters: Looks.blueShutter)
        }
    }

    /// Sandstone walls up to `hi.y` and a parapet rim round the flat roof, with a pale cap course.
    func parapetBlock(_ lo: SCNVector3, _ hi: SCNVector3) {
        block(lo, hi, .ashlar)
        let rim: CGFloat = 0.25
        let sides = [
            (SCNVector3(lo.x, hi.y, lo.z), SCNVector3(hi.x, hi.y + 0.5, lo.z + rim)),
            (SCNVector3(lo.x, hi.y, hi.z - rim), SCNVector3(hi.x, hi.y + 0.5, hi.z)),
            (SCNVector3(lo.x, hi.y, lo.z), SCNVector3(lo.x + rim, hi.y + 0.5, hi.z)),
            (SCNVector3(hi.x - rim, hi.y, lo.z), SCNVector3(hi.x, hi.y + 0.5, hi.z))
        ]
        for (low, high) in sides {
            block(low, high, .ashlar)
            block(SCNVector3(low.x - 0.05, high.y, low.z - 0.05), SCNVector3(high.x + 0.05, high.y + 0.1, high.z + 0.05), .plasterPale)
        }
    }

    /// An arched door framed in blue tile.
    func blueArch(_ face: Face, along: CGFloat, width: CGFloat, height: CGFloat) {
        onFace(
            face,
            FaceRect(along: along, y: height / 2 + 0.1, width: width + 0.5, height: height + 0.5),
            depth: 0.03,
            finish: .paint(Trade.blueTile)
        )
        archDoor(face, along: along, width: width, height: height, finish: .planks)
    }

    /// A projecting wooden lattice bay (mashrabiya) on a face, from `base` up 2 m.
    func latticeBay(_ face: Face, along: CGFloat, base: CGFloat) {
        onFace(face, FaceRect(along: along, y: base + 1.0, width: 1.6, height: 2.0), depth: 0.6, finish: .paint(Looks.lattice))
        for row in 0 ..< 4 {
            onFace(face, FaceRect(along: along, y: base + 0.35 + 0.42 * CGFloat(row), width: 1.3, height: 0.08), depth: 0.64, finish: .wood)
        }
    }

    /// A striped awning sloping off a south wall, centred at `at`.
    func awning(at centre: SCNVector3, width: CGFloat) {
        add(
            SCNBox(width: width, height: 0.06, length: 1.0, chamferRadius: 0),
            Finish.paint(Trade.awning).material(),
            at: centre,
            euler: SCNVector3(0.3, 0, 0)
        )
    }
}
