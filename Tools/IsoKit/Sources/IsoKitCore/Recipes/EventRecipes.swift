// isokit: what seasonal events add to the town (add-event-counterplay): the fire watch, the granary,
// the physician and herb garden, ruins per footprint and the fire effect. Design canvas: https://claude.ai/artifact/NfTHPHsBMu4gKzjgvxYfz5
// (option A of each).
import AppKit
import SceneKit

enum Events {
    static let ink = NSColor(red: 0.11, green: 0.09, blue: 0.08, alpha: 1)
    static let charred = NSColor(red: 0.17, green: 0.14, blue: 0.12, alpha: 1)
    static let ash = NSColor(red: 0.44, green: 0.42, blue: 0.40, alpha: 1)
    static let scorched = NSColor(red: 0.36, green: 0.31, blue: 0.27, alpha: 1)
    static let bronze = NSColor(red: 0.55, green: 0.40, blue: 0.20, alpha: 1)
    static let burlap = NSColor(red: 0.62, green: 0.54, blue: 0.40, alpha: 1)
    static let shutterBlue = NSColor(red: 0.22, green: 0.33, blue: 0.48, alpha: 1)
    static let herb = NSColor(red: 0.42, green: 0.60, blue: 0.27, alpha: 1)
    static let driedHerb = NSColor(red: 0.50, green: 0.52, blue: 0.30, alpha: 1)
    static let lavender = NSColor(red: 0.66, green: 0.52, blue: 0.80, alpha: 1)
    static let wicker = NSColor(red: 0.74, green: 0.60, blue: 0.34, alpha: 1)
    /// Outer, middle and inner flame, dark to bright.
    static let flames: [NSColor] = [
        NSColor(red: 0.80, green: 0.22, blue: 0.04, alpha: 1),
        NSColor(red: 1.0, green: 0.52, blue: 0.10, alpha: 1),
        NSColor(red: 1.0, green: 0.85, blue: 0.42, alpha: 1)
    ]
}

extension Recipes {
    /// Ruins come in one sprite per footprint that can burn: `building-ruins` is the 2 x 2 ruin of a
    /// house or workshop, `-1x1` a fire watch's, `-3x3` a warehouse's.
    struct RuinSize {
        let tiles: Int, heightPx: Int
        /// Height relative to the 2 x 2 ruin.
        let rise: CGFloat
    }

    static let ruinSizes = [
        RuinSize(tiles: 1, heightPx: 80, rise: 0.8),
        RuinSize(tiles: 2, heightPx: 112, rise: 1),
        RuinSize(tiles: 3, heightPx: 144, rise: 1.15)
    ]

    static let events: [Recipe] = [
        Recipe(id: "building-fire-watch", cell: SpriteCell(footprint: 1, heightPx: 176)) { kit, _ in fireWatch(kit) },
        Recipe(id: "building-granary", cell: SpriteCell(footprint: 2, heightPx: 144)) { kit, _ in granary(kit) },
        Recipe(id: "building-physician", cell: SpriteCell(footprint: 2, heightPx: 128)) { kit, _ in physician(kit) },
        Recipe(id: "building-herb-garden", cell: SpriteCell(footprint: 2, heightPx: 96)) { kit, _ in herbGarden(kit) }
    ] + ruinSizes.map { size in
        Recipe(
            id: ruinsID(tiles: size.tiles),
            entry: "building-ruins",
            cell: SpriteCell(footprint: size.tiles, heightPx: size.heightPx),
            constructionFrames: 0
        ) { kit, _ in ruins(kit, tiles: size.tiles, rise: size.rise) }
    }

    static func ruinsID(tiles: Int) -> String {
        tiles == 2 ? "building-ruins" : "building-ruins-\(tiles)x\(tiles)"
    }

    /// A timber lattice tower on one tile: tiled hip roof, a bronze bell, a lantern, a ladder, a water
    /// barrel and a leather bucket.
    static func fireWatch(_ kit: Builder) {
        let lo: CGFloat = 1.05, hi: CGFloat = 2.95
        kit.block(SCNVector3(lo - 0.35, 0, lo - 0.35), SCNVector3(hi + 0.35, 0.25, hi + 0.35), .rubble)
        for col in [lo, hi] {
            for row in [lo, hi] {
                kit.block(SCNVector3(col - 0.15, 0, row - 0.15), SCNVector3(col + 0.15, 8.0, row + 0.15), .timber)
            }
        }
        for base: CGFloat in [0.25, 4.1] {
            kit.timberFrame(.south(wallZ: hi + 0.15), span: lo ... hi, base: base, height: 3.75, posts: 2)
            kit.timberFrame(.east(wallX: hi + 0.15), span: lo ... hi, base: base, height: 3.75, posts: 2)
        }
        let edge: CGFloat = 0.5
        kit.block(SCNVector3(lo - edge, 7.9, lo - edge), SCNVector3(hi + edge, 8.1, hi + edge), .planks)
        kit.block(SCNVector3(lo - edge, 8.1, hi + edge - 0.08), SCNVector3(hi + edge, 8.9, hi + edge), .planks)
        kit.block(SCNVector3(hi + edge - 0.08, 8.1, lo - edge), SCNVector3(hi + edge, 8.9, hi + edge), .planks)
        for col in [lo - edge + 0.1, hi + edge - 0.1] {
            for row in [lo - edge + 0.1, hi + edge - 0.1] {
                kit.block(SCNVector3(col - 0.08, 8.1, row - 0.08), SCNVector3(col + 0.08, 10.1, row + 0.08), .timber)
            }
        }
        kit.hipRoof(RoofSpec(
            lo: SCNVector3(lo - edge, 10.1, lo - edge), hi: SCNVector3(hi + edge, 0, hi + edge), pitchDegrees: 50, overhang: 0.35,
            finish: .tile
        ))
        let mid = (lo + hi) / 2
        kit.block(SCNVector3(lo - edge, 9.75, mid - 0.05), SCNVector3(hi + edge, 9.88, mid + 0.05), .timber)
        kit.add(
            SCNCone(topRadius: 0.14, bottomRadius: 0.36, height: 0.55),
            Finish.paint(Events.bronze).material(),
            at: SCNVector3(mid, 9.35, mid)
        )
        // The lantern: its pane is the one the night lights light.
        kit.block(SCNVector3(hi + 0.1, 8.9, hi + 0.1), SCNVector3(hi + 0.38, 9.35, hi + 0.38), .glass)
        for x in [mid - 0.3, mid + 0.3] {
            kit.block(SCNVector3(x - 0.05, 0, hi + 0.38), SCNVector3(x + 0.05, 7.9, hi + 0.48), .wood)
        }
        for rung in stride(from: CGFloat(0.4), to: 7.8, by: 0.5) {
            kit.block(SCNVector3(mid - 0.3, rung, hi + 0.39), SCNVector3(mid + 0.3, rung + 0.06, hi + 0.47), .wood)
        }
        kit.barrel(at: SCNVector3(3.55, 0, 2.9))
        kit.add(
            SCNCone(topRadius: 0.17, bottomRadius: 0.13, height: 0.3), Finish.paint(Cloth.bucket).material(), at: SCNVector3(
                3.5,
                0.15,
                3.6
            )
        )
    }

    /// A weatherboarded store raised on staddle stones under a steep thatch, steps to the door, grain
    /// sacks and a crate.
    static func granary(_ kit: Builder) {
        let lo: CGFloat = 1.7, hi: CGFloat = 6.3, floor: CGFloat = 0.85, eave: CGFloat = 3.6
        for col in [lo + 0.3, 4.0, hi - 0.3] {
            for row in [lo + 0.3, 4.0, hi - 0.3] {
                kit.add(SCNCylinder(radius: 0.17, height: 0.62), Finish.rubble.material(), at: SCNVector3(col, 0.31, row))
                kit.add(SCNCylinder(radius: 0.36, height: 0.14), Finish.rubble.material(), at: SCNVector3(col, 0.69, row))
            }
        }
        kit.block(SCNVector3(lo - 0.1, 0.76, lo - 0.1), SCNVector3(hi + 0.1, floor, hi + 0.1), .timber)
        kit.block(SCNVector3(lo, floor, lo), SCNVector3(hi, eave, hi), .planks, metresPerRepeat: 1.2)
        kit.timberFrame(.south(wallZ: hi), span: lo ... hi, base: floor, height: eave - floor, posts: 4)
        kit.timberFrame(.east(wallX: hi), span: lo ... hi, base: floor, height: eave - floor, posts: 4)
        kit.door(.south(wallZ: hi), along: 4.0, base: floor, width: 1.0, height: 1.9)
        kit.gableRoof(RoofSpec(lo: SCNVector3(lo, eave, lo), hi: SCNVector3(hi, 0, hi), pitchDegrees: 50, finish: .thatch))
        kit.block(SCNVector3(3.4, 0, hi + 0.05), SCNVector3(4.6, 0.28, hi + 1.1), .wood)
        kit.block(SCNVector3(3.4, 0.28, hi + 0.05), SCNVector3(4.6, 0.56, hi + 0.6), .wood)
        for spot in [SCNVector3(5.4, 0.28, 7.1), SCNVector3(6.0, 0.28, 6.85), SCNVector3(5.7, 0.62, 7.0)] {
            kit.ball(spot, radius: 0.32, Events.burlap, scale: SCNVector3(1, 0.85, 0.9))
        }
        kit.crate(at: SCNVector3(2.4, 0, 7.0))
    }

    /// A half-timbered house under a tile roof with blue shutters, herb bundles drying under the
    /// eave, a hanging sign with a bronze mortar, a lavender bed and a drying rack (canvas option A).
    static func physician(_ kit: Builder) {
        let lo: CGFloat = 1.0, hi: CGFloat = 5.4, base: CGFloat = 0.3, eave: CGFloat = 3.1
        kit.block(SCNVector3(lo - 0.15, 0, lo - 0.15), SCNVector3(hi + 0.15, base, hi + 0.15), .rubble)
        kit.block(SCNVector3(lo, base, lo), SCNVector3(hi, eave, hi), .plaster)
        kit.timberFrame(.south(wallZ: hi), span: lo ... hi, base: base, height: eave - base, posts: 4)
        kit.timberFrame(.east(wallX: hi), span: lo ... hi, base: base, height: eave - base, posts: 4)
        kit.door(.south(wallZ: hi), along: 2.3, base: base, width: 0.9, height: 1.9)
        kit.window(.south(wallZ: hi), along: 4.2, y: 1.6, shutters: Events.shutterBlue)
        kit.window(.east(wallX: hi), along: 2.2, y: 1.6, shutters: Events.shutterBlue)
        kit.window(.east(wallX: hi), along: 4.2, y: 1.6, shutters: Events.shutterBlue)
        kit.gableRoof(RoofSpec(lo: SCNVector3(lo, eave, lo), hi: SCNVector3(hi, 0, hi), pitchDegrees: 45, finish: .tile))
        kit.chimney(x: 2.0, depth: 1.8, from: eave, to: eave + 2.4, finish: .rubble)
        // Herb bundles drying under the east eave.
        for row in stride(from: lo + 0.5, to: hi - 0.2, by: 0.7) {
            kit.block(SCNVector3(hi + 0.08, eave - 0.75, row), SCNVector3(hi + 0.3, eave - 0.15, row + 0.3), .paint(Events.driedHerb))
        }
        // The sign: a post, an arm and a bronze mortar with its pestle.
        kit.block(SCNVector3(3.2, 0, hi + 0.9), SCNVector3(3.35, 2.6, hi + 1.05), .timber)
        kit.block(SCNVector3(3.2, 2.45, hi + 0.9), SCNVector3(4.2, 2.6, hi + 1.05), .timber)
        let mortar = SCNCone(topRadius: 0.3, bottomRadius: 0.18, height: 0.38)
        kit.add(mortar, Finish.paint(Events.bronze).material(), at: SCNVector3(3.95, 2.05, hi + 0.97))
        kit.add(
            SCNBox(width: 0.07, height: 0.5, length: 0.07, chamferRadius: 0), Finish.paint(Events.bronze).material(),
            at: SCNVector3(4.0, 2.3, hi + 0.97), euler: SCNVector3(0, 0, -0.5)
        )
        // A lavender bed along the east side and a drying rack behind it.
        kit.ground(SCNVector3(6.0, 0, 1.0), SCNVector3(7.4, 0, 5.6), .paint(Palette.soil))
        for row in stride(from: CGFloat(1.4), to: 5.4, by: 0.6) {
            for x in [CGFloat(6.35), 7.0] {
                kit.ball(SCNVector3(x, 0.2, row), radius: 0.24, Events.herb, scale: SCNVector3(1, 0.8, 1))
                kit.ball(SCNVector3(x, 0.42, row), radius: 0.1, Events.lavender, scale: SCNVector3(1, 1.4, 1))
            }
        }
        kit.block(SCNVector3(6.1, 0, 6.3), SCNVector3(6.2, 1.5, 6.4), .timber)
        kit.block(SCNVector3(7.3, 0, 6.3), SCNVector3(7.4, 1.5, 6.4), .timber)
        kit.block(SCNVector3(6.1, 1.4, 6.3), SCNVector3(7.4, 1.5, 6.4), .timber)
        for x in stride(from: CGFloat(6.35), to: 7.3, by: 0.3) {
            kit.block(SCNVector3(x, 0.95, 6.28), SCNVector3(x + 0.16, 1.4, 6.42), .paint(Events.driedHerb))
        }
    }

    /// A low fenced plot of herb rows between tall lavender rows, a small drying frame hung with
    /// bunches and a wicker basket, so it reads neither as a farm nor as a tea garden (canvas, herb
    /// garden). The lavender stands tall and purple so the plot never reads as a cabbage field.
    static func herbGarden(_ kit: Builder) {
        kit.ground(SCNVector3(0.6, 0, 0.6), SCNVector3(7.4, 0, 7.4), .paint(Palette.soil))
        for (index, row) in stride(from: CGFloat(1.2), to: 7.0, by: 1.1).enumerated() {
            if index.isMultiple(of: 2) {
                for x in stride(from: CGFloat(1.0), to: 5.4, by: 0.55) {
                    kit.ball(SCNVector3(x, 0.18, row), radius: 0.24, Events.herb, scale: SCNVector3(1, 0.7, 1))
                }
            } else {
                for x in stride(from: CGFloat(1.0), to: 5.4, by: 0.42) {
                    kit.ball(SCNVector3(x, 0.2, row), radius: 0.16, Events.herb, scale: SCNVector3(1, 0.9, 1))
                    kit.ball(SCNVector3(x, 0.62, row), radius: 0.15, Events.lavender, scale: SCNVector3(0.9, 2.6, 0.9))
                }
            }
        }
        kit.fence(from: SCNVector3(0.4, 0, 7.6), to: SCNVector3(7.6, 0, 7.6), height: 0.6)
        kit.fence(from: SCNVector3(7.6, 0, 0.4), to: SCNVector3(7.6, 0, 7.6), height: 0.6)
        kit.block(SCNVector3(6.0, 0, 1.4), SCNVector3(6.12, 1.8, 1.52), .timber)
        kit.block(SCNVector3(6.0, 0, 4.4), SCNVector3(6.12, 1.8, 4.52), .timber)
        kit.block(SCNVector3(6.0, 1.7, 1.4), SCNVector3(6.12, 1.82, 4.52), .timber)
        for row in stride(from: CGFloat(1.7), to: 4.3, by: 0.45) {
            kit.block(SCNVector3(5.98, 1.15, row), SCNVector3(6.14, 1.7, row + 0.2), .paint(Events.driedHerb))
        }
        kit.add(
            SCNCylinder(radius: 0.38, height: 0.42), Finish.paint(Events.wicker).material(), at: SCNVector3(6.6, 0.21, 6.0)
        )
    }

    /// What a burnt building leaves on `tiles` x `tiles`: the 2 x 2 ruin of the peasant house (rubble
    /// plinth, ash floor, charred posts at uneven heights, a leaning rafter, fallen beams, ash heaps,
    /// the chimney stub and a stretch of fence), spread over the footprint. A small ruin is lower and a
    /// large one taller, so the posts keep their thickness and read at sprite scale.
    static func ruins(_ kit: Builder, tiles: Int, rise: CGFloat) {
        let spread = CGFloat(tiles) / 2
        let ruin = Builder()
        ruin2x2(ruin)
        ruin.root.scale = SCNVector3(spread, rise, spread)
        kit.root.addChildNode(ruin.root)
    }

    static func ruin2x2(_ kit: Builder) {
        let lo = SCNVector3(1.4, 0, 1.8), hi = SCNVector3(6.6, 0, 6.0), base: CGFloat = 0.35
        kit.block(SCNVector3(lo.x - 0.1, 0, lo.z - 0.1), SCNVector3(hi.x + 0.1, base, hi.z + 0.1), .rubble)
        kit.block(SCNVector3(lo.x, base, lo.z), SCNVector3(hi.x, base + 0.05, hi.z), .paint(Events.charred))
        // Charred posts at uneven heights.
        let posts: [(spot: SCNVector3, height: CGFloat)] = [
            (SCNVector3(lo.x, 0, lo.z), 2.9), (SCNVector3(hi.x, 0, lo.z), 2.1), (SCNVector3(lo.x, 0, hi.z), 1.7),
            (SCNVector3(hi.x, 0, hi.z), 2.6), (SCNVector3(3.2, 0, hi.z), 1.1), (SCNVector3(4.9, 0, hi.z), 2.8),
            (SCNVector3(hi.x, 0, 3.9), 1.4)
        ]
        for (spot, height) in posts {
            kit.block(
                SCNVector3(spot.x - 0.14, base, spot.z - 0.14), SCNVector3(spot.x + 0.14, base + height, spot.z + 0.14), .paint(Events.ink)
            )
        }
        kit.block(SCNVector3(4.75, base + 2.62, hi.z - 0.1), SCNVector3(hi.x + 0.1, base + 2.8, hi.z + 0.1), .paint(Events.ink))
        kit.block(SCNVector3(lo.x - 0.1, base + 2.7, lo.z - 0.1), SCNVector3(lo.x + 0.1, base + 2.88, 3.8), .paint(Events.ink))
        // A rafter leaning from the back corner, and beams fallen across the floor.
        kit.add(
            SCNBox(width: 0.18, height: 3.6, length: 0.18, chamferRadius: 0),
            Finish.paint(Events.ink).material(),
            at: SCNVector3(2.6, base + 1.5, 3.0),
            euler: SCNVector3(0.55, 0, -0.45)
        )
        for (centre, yaw) in [(SCNVector3(3.6, base + 0.12, 5.0), CGFloat(0.4)), (SCNVector3(5.0, base + 0.12, 3.6), CGFloat(-0.9))] {
            kit.add(
                SCNBox(width: 2.8, height: 0.18, length: 0.2, chamferRadius: 0), Finish.paint(Events.ink).material(), at: centre,
                euler: SCNVector3(0, yaw, 0)
            )
        }
        for (centre, size) in [
            (SCNVector3(2.6, base, 5.0), CGFloat(0.7)),
            (SCNVector3(5.6, base, 4.8), 0.55),
            (SCNVector3(4.2, base, 2.8), 0.8)
        ] {
            kit.ball(centre, radius: size, Events.ash, scale: SCNVector3(1, 0.32, 1))
        }
        kit.block(SCNVector3(hi.x - 0.15, base, 2.6), SCNVector3(hi.x + 0.02, base + 0.9, 5.2), .paint(Events.scorched))
        kit.chimney(x: lo.x + 3.9, depth: (lo.z + hi.z) / 2 + 0.5, from: base, to: 3.4)
        kit.fence(from: SCNVector3(0.4, 0, 7.6), to: SCNVector3(3.0, 0, 7.6))
    }
}

// MARK: the fire effect

extension Recipes {
    static let fireFrames = 3
    /// 80 x 80 pt: a row of flame tongues about 4.5 m along a ridge running +x, as a house's does, and up
    /// to 5 m tall. The row's middle stands on `fireGround`, 14 pt above the cell's bottom edge; the
    /// renderer anchors it there.
    static let fireCell = SpriteCell(footprint: 1, heightPx: 80, widthPx: 80)
    static let fireGround = ground(lift: 14, left: 0)

    /// Flame tongues licking up along a roof ridge, three frames of a flicker. Self-lit, flat and casting
    /// no shadow; the game adds the smoke column and the glow.
    static let fire = Recipe(
        id: "effect-fire",
        cell: fireCell,
        constructionFrames: 0,
        operationalFrames: fireFrames,
        moving: MovingPart(name: "flames") { kit, frame in flames(kit, frame: frame) },
        plot: nil,
        unit: true
    ) { _, _ in }

    /// One tongue of the row: where it stands along the ridge (m), how tall it burns at rest (m), and its
    /// base width (m).
    private struct Tongue {
        let along: CGFloat, height: CGFloat, width: CGFloat
    }

    /// Tall in the middle of the ridge, lower toward its ends, as a roof burns from its heart.
    private static let tongues = [
        Tongue(along: -2.1, height: 1.9, width: 0.9), Tongue(along: -1.35, height: 3.0, width: 1.1),
        Tongue(along: -0.55, height: 4.1, width: 1.3), Tongue(along: 0.2, height: 4.7, width: 1.4),
        Tongue(along: 0.95, height: 3.6, width: 1.2), Tongue(along: 1.65, height: 2.6, width: 1.0),
        Tongue(along: 2.25, height: 1.6, width: 0.8)
    ]

    /// The row in frame `frame`: each tongue keeps its place and flickers in height and bend.
    static func flames(_ kit: Builder, frame: Int) {
        var rng = Rng(state: 7 &+ UInt64(frame) &* 0x9E37)
        for tongue in tongues {
            let height = tongue.height * (0.82 + rng.next() * 0.3)
            let bend = 0.35 + rng.next() * 0.6
            // Some tongues rise from just behind the ridge, so the row's foot isn't a ruled line.
            let foot = SCNVector3(tongue.along, rng.next() * 0.35, -rng.next() * 0.5)
            flame(kit, at: fireGround + foot, height: height, width: tongue.width, bend: bend)
        }
    }

    /// One tongue: three flat, curved, tapering shapes facing the camera, dark red outside, orange, and a
    /// pale core, each a little in front of the last. Flat and unshaded, so it never stripes.
    static func flame(_ kit: Builder, at base: SCNVector3, height: CGFloat, width: CGFloat, bend: CGFloat) {
        let towardCamera = SCNVector3(Iso.invRoot2, 0, Iso.invRoot2)
        let layers: [(size: CGFloat, lift: CGFloat)] = [(1.0, 0), (0.72, 0.03), (0.4, 0.04)]
        for (index, (colour, layer)) in zip(Events.flames, layers).enumerated() {
            let shape = SCNShape(path: tonguePath(width: width * layer.size, height: height * layer.size, bend: bend), extrusionDepth: 0.01)
            let node = kit.add(
                shape,
                Finish.flame(colour).material(),
                at: base + towardCamera * (0.04 * CGFloat(index)) + SCNVector3(0, height * layer.lift, 0),
                euler: SCNVector3(0, CGFloat.pi / 4, 0)
            )
            node.castsShadow = false
        }
    }

    /// A flame tongue in its own plane: a rounded base, swelling sides, and a tip bent `bend` of its
    /// height toward +x, the way the wind blows the smoke.
    static func tonguePath(width: CGFloat, height: CGFloat, bend: CGFloat) -> NSBezierPath {
        let half = width / 2, tip = NSPoint(x: bend * height * 0.45, y: height)
        let path = NSBezierPath()
        path.flatness = 0.01
        path.move(to: NSPoint(x: 0, y: -half * 0.3))
        path.curve(
            to: NSPoint(x: -half, y: height * 0.2),
            controlPoint1: NSPoint(x: -half * 0.7, y: -half * 0.3),
            controlPoint2: NSPoint(x: -half, y: 0)
        )
        // The left side swells, then sweeps toward the bent tip in an S.
        path.curve(
            to: tip,
            controlPoint1: NSPoint(x: -half * 1.05, y: height * 0.5),
            controlPoint2: NSPoint(x: tip.x - half * 0.9, y: height * 0.7)
        )
        path.curve(
            to: NSPoint(x: half, y: height * 0.2),
            controlPoint1: NSPoint(x: tip.x - half * 0.35, y: height * 0.62),
            controlPoint2: NSPoint(x: half * 1.05, y: height * 0.48)
        )
        path.curve(
            to: NSPoint(x: 0, y: -half * 0.3),
            controlPoint1: NSPoint(x: half, y: 0),
            controlPoint2: NSPoint(x: half * 0.7, y: -half * 0.3)
        )
        path.close()
        return path
    }
}
