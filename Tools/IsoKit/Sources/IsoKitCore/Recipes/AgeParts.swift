import AppKit
import SceneKit

// The parts that mark a house's age and culture: gables, towers, balconies, roof-top fittings.

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
    func steppedGable(_ box: AgeBox, pitch: CGFloat) {
        let half = (box.hi.x - box.lo.x) / 2, steps = 4, rise = half * tan(pitch * CGFloat.pi / 180) / CGFloat(steps)
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

    /// The antiquity yard: a log pile by the hut (tier 1), a low rubble wall round the front yard
    /// (tier 2), and a columned portico along the courtyard front (tier 3).
    func antiquityYard(_ box: AgeBox) {
        switch box.tier {
        case 1:
            logStack(at: SCNVector3(box.hi.x + 0.3, 0, box.lo.z + 0.6), length: 1.4, rows: 2, alongX: false)
        case 2:
            block(SCNVector3(0.4, 0, box.hi.z + 0.9), SCNVector3(7.6, 0.9, box.hi.z + 1.15), .rubble)
            block(SCNVector3(7.35, 0, 0.6), SCNVector3(7.6, 0.9, box.hi.z + 1.15), .rubble)
        default:
            colonnade(from: SCNVector3(box.lo.x + 0.4, 0, box.hi.z + 0.8), to: SCNVector3(box.hi.x - 0.4, 0, box.hi.z + 0.8))
        }
    }

    /// A loggia tower on the back corner of a roof terrace: open arches under a low tile hip.
    func loggiaTower(_ box: AgeBox) {
        let lo = SCNVector3(box.lo.x + 0.5, box.top, box.lo.z + 0.5), hi = SCNVector3(box.lo.x + 2.9, box.top + 2.2, box.lo.z + 2.9)
        block(lo, hi, .paint(Civic.ochre))
        arcade(Face.south(wallZ: hi.z), from: lo.x + 0.2, to: hi.x - 0.2, base: lo.y + 0.1)
        arcade(Face.east(wallX: hi.x), from: lo.z + 0.2, to: hi.z - 0.2, base: lo.y + 0.1)
        hipRoof(RoofSpec(lo: SCNVector3(lo.x, hi.y, lo.z), hi: hi, pitchDegrees: 22, overhang: 0.3, finish: .tile))
    }

    /// Two rows of solar panels on a flat roof, the low edge on the deck and the high edge on legs.
    func solarPanels(_ box: AgeBox) {
        let tilt: CGFloat = 0.4, rise = 0.5 * sin(tilt)
        for row in 0 ..< 2 {
            let depth = box.lo.z + 1.4 + CGFloat(row) * 1.4, centre = box.top + 0.04 + rise
            add(
                SCNBox(width: 2.6, height: 0.06, length: 1.0, chamferRadius: 0), Finish.paint(AgePalette.solar).material(),
                at: SCNVector3(box.lo.x + 2.4, centre, depth), euler: SCNVector3(-tilt, 0, 0)
            )
            for along in [box.lo.x + 1.3, box.lo.x + 3.5] {
                block(
                    SCNVector3(along - 0.04, box.top, depth + 0.38),
                    SCNVector3(along + 0.04, centre + rise * 0.8, depth + 0.44),
                    .paint(Trade.iron)
                )
            }
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
