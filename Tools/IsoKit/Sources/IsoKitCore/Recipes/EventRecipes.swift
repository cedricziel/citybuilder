// isokit: what seasonal events add to the town (add-event-counterplay): the fire watch, the granary,
// ruins per footprint and the fire effect. Design canvas: https://claude.ai/artifact/NfTHPHsBMu4gKzjgvxYfz5
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
        Recipe(id: "building-granary", cell: SpriteCell(footprint: 2, heightPx: 144)) { kit, _ in granary(kit) }
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
    /// 80 x 64 pt: room for a cluster of flame tongues about 3 m across and 2.5 m tall. The cluster stands
    /// on `fireGround`, 8 pt above the cell's bottom edge; the renderer anchors it there.
    static let fireCell = SpriteCell(footprint: 1, heightPx: 64, widthPx: 80)
    static let fireGround = ground(lift: 8, left: 0)

    /// Flame tongues licking up from a roof, three frames of a flicker. Self-lit and casting no shadow;
    /// the game adds the smoke column and the glow as particles.
    static let fire = Recipe(
        id: "effect-fire",
        cell: fireCell,
        constructionFrames: 0,
        operationalFrames: fireFrames,
        moving: MovingPart(name: "flames") { kit, frame in flames(kit, frame: frame) },
        plot: nil,
        unit: true
    ) { _, _ in }

    static func flames(_ kit: Builder, frame: Int) {
        var rng = Rng(state: 7 &+ UInt64(frame) &* 0x9E37)
        // Across the screen is +x -z; the tongues spread that way, with a little depth.
        let across = SCNVector3(Iso.invRoot2, 0, -Iso.invRoot2)
        for offset: CGFloat in [-1.3, -0.75, -0.2, 0.35, 0.9, 1.35] {
            let depth = rng.jitter(0.6)
            let base = fireGround + across * (offset + rng.jitter(0.25)) + SCNVector3(depth, 0, depth)
            let tall = 1.0 - abs(offset) / 2.2
            flame(
                kit,
                at: base,
                height: (1.3 + rng.next() * 1.7) * tall + 0.4,
                radius: 0.26 + rng.next() * 0.16,
                lean: 0.25 + rng.next() * 0.2
            )
        }
    }

    /// One tongue: three nested cones, dark outside and bright at the core, leaning with the wind. Each
    /// inner cone moves toward the camera until its front meets the outer one's, so the core shows.
    static func flame(_ kit: Builder, at base: SCNVector3, height: CGFloat, radius: CGFloat, lean: CGFloat) {
        let towardCamera = SCNVector3(Iso.invRoot2, 0, Iso.invRoot2)
        let layers: [(width: CGFloat, tall: CGFloat)] = [(1.0, 1.0), (0.7, 0.8), (0.4, 0.55)]
        for (colour, layer) in zip(Events.flames, layers) {
            let length = height * layer.tall
            let forward = radius * (1 - layer.width) + (layer.width < 1 ? 0.03 : 0)
            let node = kit.add(
                SCNCone(topRadius: 0, bottomRadius: radius * layer.width, height: length),
                Finish.flame(colour).material(),
                at: base + towardCamera * forward + SCNVector3(length / 2 * sin(lean), length / 2 * cos(lean), 0),
                euler: SCNVector3(0, 0, -lean)
            )
            node.castsShadow = false
        }
    }
}
