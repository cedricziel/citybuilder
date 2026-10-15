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
    var extras: (Builder, AgeBox) -> Void = { _, _ in }
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
        let (lo, hi) = ageFootprint(tier)
        let storeys = style.storeys[tier - 1], storey: CGFloat = style.bands ? 3.0 : 2.8
        let box = AgeBox(lo: lo, hi: hi, top: 0.3 + CGFloat(storeys) * storey, storey: storey, tier: tier)
        kit.block(SCNVector3(lo.x - 0.1, 0, lo.z - 0.1), SCNVector3(hi.x + 0.1, 0.3, hi.z + 0.1), .rubble)
        kit.block(SCNVector3(lo.x, 0.3, lo.z), SCNVector3(hi.x, box.floor(1), hi.z), style.ground)
        if storeys > 1 { kit.block(SCNVector3(lo.x, box.floor(1), lo.z), SCNVector3(hi.x, box.top, hi.z), style.walls) }
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
                lo: SCNVector3(lo.x, box.top, lo.z), hi: hi, pitchDegrees: pitch, finish: finish, gableFinish: style.walls,
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
        // Antiquity: stone and thatch, earth and timber, a Roman domus, mud brick.
        "antiquity": AgeStyle(
            ground: .rubble,
            walls: .rubble,
            storeys: [1, 1, 1],
            roof: { _ in .hip(.thatch, pitch: 44) },
            extras: { kit, box in
                kit.logStack(at: SCNVector3(box.hi.x + 0.2, 0, box.lo.z + 1.0), length: 1.6, rows: 2, alongX: false)
                if box.tier == 3 { kit.porch(alongX: (box.lo.x + 0.4) ... (box.lo.x + 2.0), wallZ: box.hi.z, depth: 1.0, height: 2.4) }
            }
        ),
        "antiquity-east-asian": AgeStyle(
            ground: .paint(AgePalette.daub), walls: .paint(AgePalette.daub), storeys: [1, 1, 1],
            roof: { $0 == 3 ? .hip(.slate, pitch: 30) : .hip(.thatch, pitch: 48) },
            extras: { kit, box in kit.posts(box, finish: box.tier == 3 ? .paint(Civic.lacquer) : .timber) }
        ),
        "antiquity-mediterranean": AgeStyle(
            ground: .plasterPale,
            walls: .plasterPale,
            storeys: [1, 1, 1],
            roof: { _ in .hip(.tile, pitch: 22) },
            extras: { kit, box in
                kit.onFace(
                    box.south,
                    FaceRect(along: (box.lo.x + box.hi.x) / 2, y: 0.7, width: box.hi.x - box.lo.x, height: 0.8),
                    depth: 0.04,
                    finish: .paint(AgePalette.dado)
                )
                if box.tier == 3 { kit.colonnade(
                    from: SCNVector3(box.lo.x + 0.4, 0, box.hi.z + 0.8),
                    to: SCNVector3(box.hi.x - 0.4, 0, box.hi.z + 0.8)
                ) }
            }
        ),
        "antiquity-middle-eastern": AgeStyle(
            ground: .paint(AgePalette.mud),
            walls: .paint(AgePalette.mud),
            storeys: [1, 1, 2],
            roof: { _ in .flat(deck: .yard) },
            extras: { kit, box in
                for along in stride(from: box.lo.x + 0.6, to: box.hi.x, by: 0.9) {
                    kit.block(
                        SCNVector3(along - 0.07, box.top - 0.4, box.hi.z),
                        SCNVector3(along + 0.07, box.top - 0.26, box.hi.z + 0.3),
                        .timber
                    )
                }
                if box.tier >= 2 { kit.palm(at: SCNVector3(box.hi.x + 0.4, 0, box.hi.z + 0.4)) }
            }
        ),
        // Renaissance: stepped gables, lattice shopfronts, ochre palazzi, carved stone and lattice bays.
        "renaissance": AgeStyle(
            ground: .ashlar, walls: .plasterPale, storeys: [2, 2, 3], roof: { _ in .gable(.tile, pitch: 56, alongX: false) },
            shutters: Palette.shutterGreen,
            extras: { kit, box in kit.steppedGable(box) }
        ),
        "renaissance-east-asian": AgeStyle(
            ground: .timber,
            walls: .plasterPale,
            storeys: [2, 2, 2],
            roof: { $0 == 3 ? .hip(.slate, pitch: 32) : .gable(.slate, pitch: 34) },
            chimney: .brick,
            extras: { kit, box in
                kit.pent(SCNVector3(box.lo.x, box.floor(1), box.lo.z), box.hi)
            }
        ),
        "renaissance-mediterranean": AgeStyle(
            ground: .ashlar, walls: .paint(Civic.ochre), storeys: [2, 3, 3], roof: { _ in .hip(.tile, pitch: 22) },
            shutters: Looks.blueShutter,
            extras: { kit, box in kit.cornice(box, finish: .paint(Civic.travertine)) }
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
                kit.chimney(x: box.lo.x + 1.4, depth: (box.lo.z + box.hi.z) / 2 + 0.7, from: box.top, to: box.top + 2.6, finish: .brick)
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
                    SCNVector3(box.lo.x + 1.0, box.top, box.lo.z + 1.0),
                    SCNVector3(box.lo.x + 3.4, box.top + 0.08, box.lo.z + 3.4),
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

// MARK: age parts

extension Builder {
    /// A parapet rim with a pale cap round a flat roof at `top`.
    func rim(_ lo: SCNVector3, _ hi: SCNVector3, top: CGFloat) {
        let rim: CGFloat = 0.22
        for (low, high) in [
            (SCNVector3(lo.x, top, lo.z), SCNVector3(hi.x, top + 0.45, lo.z + rim)),
            (SCNVector3(lo.x, top, hi.z - rim), SCNVector3(hi.x, top + 0.45, hi.z)),
            (SCNVector3(lo.x, top, lo.z), SCNVector3(lo.x + rim, top + 0.45, hi.z)),
            (SCNVector3(hi.x - rim, top, lo.z), SCNVector3(hi.x, top + 0.45, hi.z))
        ] {
            block(low, high, .ashlar)
            block(SCNVector3(low.x - 0.04, high.y, low.z - 0.04), SCNVector3(high.x + 0.04, high.y + 0.08, high.z + 0.04), .plasterPale)
        }
    }

    /// Dark (or red) posts along the two visible faces.
    func posts(_ box: AgeBox, finish: Finish) {
        for along in stride(from: box.lo.x, through: box.hi.x, by: (box.hi.x - box.lo.x) / 4) {
            block(SCNVector3(along - 0.1, 0.3, box.hi.z), SCNVector3(along + 0.1, box.top, box.hi.z + 0.1), finish)
        }
        for along in stride(from: box.lo.z, through: box.hi.z, by: (box.hi.z - box.lo.z) / 3) {
            block(SCNVector3(box.hi.x, 0.3, along - 0.1), SCNVector3(box.hi.x + 0.1, box.top, along + 0.1), finish)
        }
    }

    /// A stepped gable over the south face, for a roof whose ridge runs along z: each step stands
    /// above the roof slope and out past its overhang.
    func steppedGable(_ box: AgeBox) {
        let half = (box.hi.x - box.lo.x) / 2, steps = 4, rise = half * tan(56 * CGFloat.pi / 180) / CGFloat(steps)
        for step in 0 ..< steps {
            let inset = half * CGFloat(step) / CGFloat(steps), base = box.top + CGFloat(step) * rise
            block(
                SCNVector3(box.lo.x + inset, base, box.hi.z - 0.3),
                SCNVector3(box.hi.x - inset, base + rise + 0.3, box.hi.z + 0.55),
                .plasterPale
            )
        }
    }

    /// A brick clock turret with a pale face and a slate pyramid cap, standing on a roof.
    func clockTurret(at base: SCNVector3) {
        block(base + SCNVector3(-0.6, 0, -0.6), base + SCNVector3(0.6, 3.0, 0.6), .brick)
        onFace(
            Face.south(wallZ: base.z + 0.6),
            FaceRect(along: base.x, y: base.y + 2.2, width: 0.7, height: 0.7),
            depth: 0.04,
            finish: .plasterPale
        )
        add(SCNPyramid(width: 1.5, height: 1.0, length: 1.5), Finish.slate.material(), at: base + SCNVector3(0, 3.0, 0))
    }

    /// A pale band at every storey line on the two visible faces.
    func cornice(_ box: AgeBox, finish: Finish) {
        var y = box.floor(1)
        while y <= box.top + 0.01 {
            block(SCNVector3(box.lo.x - 0.08, y - 0.14, box.hi.z - 0.1), SCNVector3(box.hi.x + 0.08, y, box.hi.z + 0.08), finish)
            block(SCNVector3(box.hi.x - 0.1, y - 0.14, box.lo.z - 0.08), SCNVector3(box.hi.x + 0.08, y, box.hi.z + 0.08), finish)
            y += box.storey
        }
    }

    /// An iron-railed balcony slab on every upper storey of the south face.
    func balconies(_ box: AgeBox) {
        var floor = 1
        while box.floor(floor) < box.top - 0.1 {
            let y = box.floor(floor)
            block(SCNVector3(box.lo.x + 1.8, y, box.hi.z), SCNVector3(box.hi.x - 0.8, y + 0.12, box.hi.z + 0.8), .ashlar)
            block(
                SCNVector3(box.lo.x + 1.8, y + 0.84, box.hi.z + 0.74),
                SCNVector3(box.hi.x - 0.8, y + 0.9, box.hi.z + 0.8),
                .paint(Trade.iron)
            )
            for along in stride(from: box.lo.x + 1.85, through: box.hi.x - 0.85, by: 0.35) {
                block(
                    SCNVector3(along - 0.02, y + 0.12, box.hi.z + 0.75),
                    SCNVector3(along + 0.02, y + 0.84, box.hi.z + 0.79),
                    .paint(Trade.iron)
                )
            }
            floor += 1
        }
    }

    /// Two rows of tilted solar panels on a flat roof.
    func solarPanels(_ box: AgeBox) {
        for row in 0 ..< 2 {
            add(
                SCNBox(width: 2.6, height: 0.06, length: 1.0, chamferRadius: 0), Finish.paint(AgePalette.solar).material(),
                at: SCNVector3(box.lo.x + 2.4, box.top + 0.5, box.lo.z + 1.4 + CGFloat(row) * 1.4), euler: SCNVector3(-0.4, 0, 0)
            )
        }
    }

    /// A timber pergola on posts over the back of a flat roof.
    func colonnadePergola(_ box: AgeBox) {
        let lo = SCNVector3(box.lo.x + 0.6, box.top, box.lo.z + 0.6), hi = SCNVector3(box.lo.x + 3.0, box.top, box.lo.z + 2.8)
        for (x, depth) in [(lo.x, lo.z), (hi.x, lo.z), (lo.x, hi.z), (hi.x, hi.z)] {
            block(SCNVector3(x - 0.07, box.top, depth - 0.07), SCNVector3(x + 0.07, box.top + 2.0, depth + 0.07), .wood)
        }
        for along in stride(from: lo.x, through: hi.x, by: 0.4) {
            block(SCNVector3(along - 0.04, box.top + 2.0, lo.z - 0.2), SCNVector3(along + 0.04, box.top + 2.1, hi.z + 0.2), .wood)
        }
    }
}
