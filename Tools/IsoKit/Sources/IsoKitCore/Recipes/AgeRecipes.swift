// isokit: the age looks of the house, three tiers for each of four ages in each of four cultures.
// One parametric house (walls, storeys, glazing, roof, chimney) takes a style per age and culture,
// and each style adds the few parts that make it read: a stepped gable, lattice bays, a dome.
import AppKit
import SceneKit

enum AgePalette {
    static let daub = NSColor(red: 0.56, green: 0.43, blue: 0.29, alpha: 1)
    static let mud = NSColor(red: 0.58, green: 0.45, blue: 0.31, alpha: 1)
    static let dado = NSColor(red: 0.56, green: 0.18, blue: 0.14, alpha: 1)
    static let panel = NSColor(red: 0.25, green: 0.22, blue: 0.20, alpha: 1)
    static let solar = NSColor(red: 0.14, green: 0.18, blue: 0.30, alpha: 1)
    static let pool = NSColor(red: 0.30, green: 0.56, blue: 0.70, alpha: 1)
    static let glazing = NSColor(red: 0.34, green: 0.50, blue: 0.62, alpha: 1)
}

/// A house roof: a gable (ridge along x, or along z so the gable faces south), a hip, a mansard (steep
/// slate sides with dormers under a low hip), or flat behind a rim over a deck.
enum AgeRoof {
    case gable(Finish, pitch: CGFloat, alongX: Bool = true)
    case hip(Finish, pitch: CGFloat)
    case mansard
    case flat(deck: Finish)
}

/// One house's box: footprint corners (y = 0), wall top, storey height, tier.
struct AgeBox {
    let lo: SCNVector3, hi: SCNVector3, top: CGFloat, storey: CGFloat, tier: Int

    var south: Face {
        Face.south(wallZ: hi.z)
    }

    var east: Face {
        Face.east(wallX: hi.x)
    }

    /// The base of storey `index` (0 = ground floor).
    func floor(_ index: Int) -> CGFloat {
        0.3 + CGFloat(index) * storey
    }
}

struct AgeStyle {
    var ground: Finish
    var walls: Finish
    var storeys: [Int]
    var roof: (Int) -> AgeRoof
    var shutters: NSColor?
    var bands = false
    var chimney: Finish = .rubble
    /// Walls for a tier that builds in another material than the rest (the hut, the stone house).
    var tierWalls: [Int: Finish] = [:]
    /// Tier 1 is a small hut on a smaller footprint.
    var smallHut = false
    var extras: (Builder, AgeBox) -> Void = { _, _ in }

    func walls(_ tier: Int) -> Finish {
        tierWalls[tier] ?? walls
    }
}

extension Recipes {
    static let ages: [Recipe] = ["antiquity", "renaissance", "industrial", "modern"].flatMap { age in
        ["", "-east-asian", "-mediterranean", "-middle-eastern"].flatMap { culture -> [Recipe] in
            guard let style = ageStyles[age + culture] else { return [] }
            return (1 ... 3).map { tier in
                let body = { (kit: Builder) in ageHouse(kit, style, tier: tier) }
                let cell = fittedCell(body)
                return house(age + culture, tier: tier, height: cell.heightPx, body)
            }
        }
    }

    /// A 2 x 2 cell just tall enough for what `body` builds, in 16 pt steps.
    static func fittedCell(_ body: (Builder) -> Void) -> SpriteCell {
        let kit = Builder()
        body(kit)
        let probe = SpriteCell(footprint: 2, heightPx: 0)
        let top = CellFit.corners(of: kit.root).map { Projection.screen($0, in: probe).y }.max() ?? 0
        return SpriteCell(footprint: 2, heightPx: Int(((top + 6) / 16).rounded(.up)) * 16)
    }

    static func ageFootprint(_ tier: Int) -> (SCNVector3, SCNVector3) {
        switch tier {
        case 1: (SCNVector3(1.2, 0, 1.6), SCNVector3(6.6, 0, 6.0))
        case 2: (SCNVector3(1.0, 0, 1.2), SCNVector3(7.0, 0, 6.4))
        default: (SCNVector3(0.9, 0, 1.0), SCNVector3(7.1, 0, 6.8))
        }
    }

    /// Plinth, a ground floor and the upper storeys, windows on the two visible faces, a door, the roof,
    /// and a chimney through the visible side of it.
    static func ageHouse(_ kit: Builder, _ style: AgeStyle, tier: Int) {
        let (lo, hi) = style.smallHut && tier == 1 ? (SCNVector3(2.0, 0, 2.2), SCNVector3(6.2, 0, 5.8)) : ageFootprint(tier)
        let storeys = style.storeys[tier - 1], storey: CGFloat = style.bands ? 3.0 : 2.8
        let box = AgeBox(lo: lo, hi: hi, top: 0.3 + CGFloat(storeys) * storey, storey: storey, tier: tier)
        kit.block(SCNVector3(lo.x - 0.1, 0, lo.z - 0.1), SCNVector3(hi.x + 0.1, 0.3, hi.z + 0.1), .rubble)
        kit.block(SCNVector3(lo.x, 0.3, lo.z), SCNVector3(hi.x, box.floor(1), hi.z), style.tierWalls[tier] ?? style.ground)
        if storeys > 1 { kit.block(SCNVector3(lo.x, box.floor(1), lo.z), SCNVector3(hi.x, box.top, hi.z), style.walls(tier)) }
        for index in 0 ..< storeys {
            let sill = box.floor(index) + storey * 0.55
            if style.bands {
                for (face, span) in [(box.south, lo.x ... hi.x), (box.east, lo.z ... hi.z)] {
                    let rect = FaceRect(
                        along: (span.lowerBound + span.upperBound) / 2,
                        y: sill,
                        width: span.upperBound - span.lowerBound - 1.0,
                        height: 1.1
                    )
                    kit.onFace(face, rect, depth: 0.06, finish: .paint(AgePalette.glazing))
                }
                continue
            }
            for along in stride(from: lo.x + (index == 0 ? 2.4 : 1.2), to: hi.x - 0.6, by: 1.6) {
                kit.window(box.south, along: along, y: sill, lit: (index + Int(along)) % 3 == 0, shutters: style.shutters)
            }
            for along in stride(from: lo.z + 1.0, to: hi.z - 0.5, by: 1.7) {
                kit.window(box.east, along: along, y: sill, lit: false, shutters: style.shutters)
            }
        }
        kit.door(box.south, along: lo.x + 1.0, base: 0.3, width: 1.0, height: 2.0)
        ageRoof(kit, style, box)
        style.extras(kit, box)
    }

    /// The roof, and a chimney through the visible side of it.
    static func ageRoof(_ kit: Builder, _ style: AgeStyle, _ box: AgeBox) {
        let lo = box.lo, hi = box.hi, mid = (lo.z + hi.z) / 2
        switch style.roof(box.tier) {
        case let .gable(finish, pitch, alongX):
            let ridge = kit.gableRoof(RoofSpec(
                lo: SCNVector3(lo.x, box.top, lo.z), hi: hi, pitchDegrees: pitch, finish: finish, gableFinish: style.walls(box.tier),
                ridgeAlongX: alongX
            ))
            if alongX {
                kit.chimney(x: hi.x - 1.4, depth: mid + 0.7, from: box.top, to: ridge + 0.3, finish: style.chimney)
            } else {
                kit.chimney(x: (lo.x + hi.x) / 2 + 0.7, depth: hi.z - 1.6, from: box.top, to: ridge + 0.3, finish: style.chimney)
            }
        case let .hip(finish, pitch):
            kit.hipRoof(RoofSpec(lo: SCNVector3(lo.x, box.top + 0.3, lo.z), hi: hi, pitchDegrees: pitch, overhang: 0.6, finish: finish))
            kit.chimney(
                x: hi.x - 1.4,
                depth: hi.z - 1.4,
                from: box.top,
                to: box.top + 1.4 * tan(pitch * .pi / 180) + 1.2,
                finish: style.chimney
            )
        case .mansard:
            kit.block(SCNVector3(lo.x + 0.3, box.top, lo.z + 0.3), SCNVector3(hi.x - 0.3, box.top + 2.4, hi.z - 0.3), .slate)
            for along in stride(from: lo.x + 1.4, to: hi.x - 0.8, by: 1.6) {
                kit.window(Face.south(wallZ: hi.z - 0.3), along: along, y: box.top + 1.2, lit: false)
            }
            kit.hipRoof(RoofSpec(
                lo: SCNVector3(lo.x + 0.3, box.top + 2.5, lo.z + 0.3), hi: SCNVector3(hi.x - 0.3, 0, hi.z - 0.3),
                pitchDegrees: 18, overhang: 0.2, finish: .slate
            ))
            kit.chimney(x: hi.x - 1.4, depth: hi.z - 1.6, from: box.top, to: box.top + 3.8, finish: style.chimney)
        case let .flat(deck):
            kit.block(SCNVector3(lo.x, box.top, lo.z), SCNVector3(hi.x, box.top + 0.04, hi.z), deck)
            kit.rim(lo, hi, top: box.top)
            kit.chimney(x: hi.x - 0.8, depth: hi.z - 0.8, from: box.top, to: box.top + 1.1, finish: style.chimney)
        }
    }
}

// MARK: styles

extension Recipes {
    static let ageStyles: [String: AgeStyle] = [
        // Antiquity: a wattle or mud hut under thatch or reed (tier 1), a rendered stone house under fired
        // roofing behind a yard wall (tier 2), a courtyard house with a columned portico (tier 3).
        "antiquity": AgeStyle(
            ground: .plaster, walls: .plaster, storeys: [1, 1, 1],
            roof: { $0 == 1 ? .hip(.thatch, pitch: 46) : $0 == 2 ? .gable(.tile, pitch: 34) : .hip(.tile, pitch: 26) },
            tierWalls: [1: .paint(AgePalette.daub)], smallHut: true,
            extras: { kit, box in kit.antiquityYard(box) }
        ),
        "antiquity-east-asian": AgeStyle(
            ground: .plasterPale, walls: .plasterPale, storeys: [1, 1, 1],
            roof: { $0 == 1 ? .hip(.thatch, pitch: 48) : $0 == 2 ? .gable(.slate, pitch: 34) : .hip(.slate, pitch: 30) },
            tierWalls: [1: .paint(AgePalette.daub)], smallHut: true,
            extras: { kit, box in
                kit.posts(box, finish: box.tier == 3 ? .paint(Civic.lacquer) : .timber)
                kit.antiquityYard(box)
            }
        ),
        "antiquity-mediterranean": AgeStyle(
            ground: .plasterPale, walls: .plasterPale, storeys: [1, 1, 1],
            roof: { $0 == 1 ? .hip(.thatch, pitch: 40) : .hip(.tile, pitch: 22) },
            tierWalls: [1: .paint(AgePalette.daub)], smallHut: true,
            extras: { kit, box in
                if box.tier > 1 {
                    let rect = FaceRect(along: (box.lo.x + box.hi.x) / 2, y: 0.7, width: box.hi.x - box.lo.x, height: 0.8)
                    kit.onFace(box.south, rect, depth: 0.04, finish: .paint(AgePalette.dado))
                }
                kit.antiquityYard(box)
            }
        ),
        "antiquity-middle-eastern": AgeStyle(
            ground: .plaster, walls: .plaster, storeys: [1, 1, 1],
            roof: { $0 == 1 ? .flat(deck: .thatch) : .flat(deck: .yard) },
            chimney: .ashlar, tierWalls: [1: .paint(AgePalette.mud)], smallHut: true,
            extras: { kit, box in
                for along in stride(from: box.lo.x + 0.6, to: box.hi.x, by: 0.9) {
                    kit.block(
                        SCNVector3(along - 0.07, box.top - 0.4, box.hi.z),
                        SCNVector3(along + 0.07, box.top - 0.26, box.hi.z + 0.3),
                        .timber
                    )
                }
                if box.tier >= 2 { kit.palm(at: SCNVector3(box.hi.x + 0.5, 0, box.lo.z + 0.8)) }
                kit.antiquityYard(box)
            }
        ),
        // Renaissance: a narrow gable-fronted house (tier 1), a broader house of three storeys (tier 2), a
        // guild house or palazzo with its own mark (tier 3): cornices, a balcony, a loggia tower.
        "renaissance": AgeStyle(
            ground: .ashlar, walls: .plasterPale, storeys: [2, 3, 4], roof: { _ in .gable(.tile, pitch: 56, alongX: false) },
            shutters: Palette.shutterGreen,
            extras: { kit, box in
                kit.steppedGable(box, pitch: 56)
                if box.tier == 3 { kit.cornice(box, finish: .ashlar) }
            }
        ),
        "renaissance-east-asian": AgeStyle(
            ground: .timber, walls: .plasterPale, storeys: [2, 2, 2],
            roof: { $0 == 3 ? .hip(.slate, pitch: 32) : .gable(.slate, pitch: 34) },
            chimney: .brick,
            extras: { kit, box in
                kit.pent(SCNVector3(box.lo.x, box.floor(1), box.lo.z), box.hi)
                if box.tier == 2 { kit.balconies(box) }
            }
        ),
        "renaissance-mediterranean": AgeStyle(
            ground: .ashlar, walls: .paint(Civic.ochre), storeys: [2, 3, 3],
            roof: { $0 == 3 ? .flat(deck: .tile) : .hip(.tile, pitch: 22) },
            shutters: Looks.blueShutter,
            extras: { kit, box in
                kit.cornice(box, finish: .paint(Civic.travertine))
                if box.tier == 3 { kit.loggiaTower(box) }
            }
        ),
        "renaissance-middle-eastern": AgeStyle(
            ground: .ashlar,
            walls: .ashlar,
            storeys: [2, 3, 3],
            roof: { _ in .flat(deck: .yard) },
            chimney: .ashlar,
            extras: { kit, box in
                for index in 0 ..< box.tier {
                    kit.latticeBay(box.south, along: box.lo.x + 2.4 + CGFloat(index) * 1.8, base: box.floor(1) + 0.3)
                }
                if box.tier == 3 { kit.add(
                    SCNSphere(radius: 1.0),
                    Finish.paint(Trade.blueTile).material(),
                    at: SCNVector3(box.lo.x + 2.0, box.top + 0.2, box.lo.z + 2.0)
                ) }
            }
        ),
        // Industrial: brick terraces under slate, upturned slate roofs, balconies, flat tar roofs.
        "industrial": AgeStyle(
            ground: .brick,
            walls: .brick,
            storeys: [2, 3, 3],
            roof: { $0 == 3 ? .mansard : .gable(.slate, pitch: 36) },
            chimney: .brick,
            extras: { kit, box in
                // A second stack at the far gable end; the mansard has its own.
                guard box.tier < 3 else { return }
                let ridge = box.top + (box.hi.z - box.lo.z) / 2 * tan(36 * CGFloat.pi / 180)
                kit.chimney(x: box.lo.x + 1.4, depth: (box.lo.z + box.hi.z) / 2 + 0.7, from: box.top, to: ridge + 0.3, finish: .brick)
            }
        ),
        "industrial-east-asian": AgeStyle(
            ground: .brick,
            walls: .brick,
            storeys: [1, 2, 3],
            roof: { _ in .hip(.slate, pitch: 30) },
            chimney: .brick,
            extras: { kit, box in
                kit.cornice(box, finish: .ashlar)
                if box.tier == 3 { kit.clockTurret(at: SCNVector3(box.lo.x + 3.0, box.top, box.lo.z + 2.6)) }
            }
        ),
        "industrial-mediterranean": AgeStyle(
            ground: .ashlar,
            walls: .brick,
            storeys: [2, 3, 4],
            roof: { _ in .hip(.slate, pitch: 22) },
            chimney: .brick,
            extras: { kit, box in
                kit.balconies(box)
            }
        ),
        "industrial-middle-eastern": AgeStyle(
            ground: .brick,
            walls: .brick,
            storeys: [2, 3, 4],
            roof: { _ in .flat(deck: .rock) },
            chimney: .brick,
            extras: { kit, box in
                if box.tier == 3 { kit.latticeBay(box.south, along: box.lo.x + 3.6, base: box.floor(2) + 0.3) }
                kit.awning(at: SCNVector3(box.lo.x + 3.0, 2.4, box.hi.z + 0.4), width: 1.8)
            }
        ),
        // Modern: rendered concrete, glass bands, flat roofs; a flared tile canopy, sun screens and domes.
        "modern": AgeStyle(
            ground: .wood,
            walls: .plasterPale,
            storeys: [1, 3, 5],
            roof: { _ in .flat(deck: .rock) },
            bands: true,
            chimney: .plasterPale,
            extras: { kit, box in
                kit.solarPanels(box)
                if box.tier == 3 { kit.balconies(box) }
            }
        ),
        "modern-east-asian": AgeStyle(
            ground: .paint(AgePalette.panel),
            walls: .plasterPale,
            storeys: [1, 2, 5],
            roof: { _ in .hip(.slate, pitch: 24) },
            bands: true,
            chimney: .plasterPale
        ),
        "modern-mediterranean": AgeStyle(
            ground: .plasterPale,
            walls: .plasterPale,
            storeys: [1, 2, 5],
            roof: { _ in .flat(deck: .rock) },
            bands: true,
            chimney: .plasterPale,
            extras: { kit, box in
                if box.tier == 2 { kit.block(
                    SCNVector3(box.lo.x + 3.4, box.top, box.lo.z + 0.8),
                    SCNVector3(box.hi.x - 0.6, box.top + 0.08, box.lo.z + 3.0),
                    .paint(AgePalette.pool)
                ) }
                if box.tier == 3 { kit.balconies(box) } else { kit.colonnadePergola(box) }
            }
        ),
        "modern-middle-eastern": AgeStyle(
            ground: .ashlar,
            walls: .plasterPale,
            storeys: [1, 2, 5],
            roof: { _ in .flat(deck: .rock) },
            bands: true,
            chimney: .ashlar,
            extras: { kit, box in
                kit.onFace(
                    box.south,
                    FaceRect(along: (box.lo.x + box.hi.x) / 2, y: box.floor(1) - 0.2, width: box.hi.x - box.lo.x, height: 0.3),
                    depth: 0.05,
                    finish: .paint(Trade.blueTile)
                )
                kit.latticeBay(box.south, along: box.hi.x - 1.4, base: box.floor(box.tier == 1 ? 0 : 1) + 0.3)
                kit.add(
                    SCNSphere(radius: 0.8),
                    Finish.paint(Trade.blueTile).material(),
                    at: SCNVector3(box.lo.x + 1.8, box.top + 0.1, box.lo.z + 1.8)
                )
            }
        )
    ]
}
