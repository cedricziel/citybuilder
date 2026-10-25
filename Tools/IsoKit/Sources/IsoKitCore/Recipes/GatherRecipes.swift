// isokit: the gather family (farms, gardens, groves and the mine). Each is a small hut in the back
// corner of its 2 x 2 yard with its crop or workings filling the front, where the camera sees most.
import AppKit
import SceneKit

enum Crops {
    static let wheat = NSColor(red: 0.80, green: 0.66, blue: 0.36, alpha: 1)
    static let leaf = NSColor(red: 0.30, green: 0.46, blue: 0.20, alpha: 1)
    static let darkLeaf = NSColor(red: 0.16, green: 0.30, blue: 0.16, alpha: 1)
    static let grape = NSColor(red: 0.36, green: 0.12, blue: 0.20, alpha: 1)
    static let cherry = NSColor(red: 0.66, green: 0.14, blue: 0.10, alpha: 1)
    static let hopCone = NSColor(red: 0.70, green: 0.78, blue: 0.42, alpha: 1)
    static let ore = NSColor(red: 0.30, green: 0.27, blue: 0.25, alpha: 1)
    static let opening = NSColor(white: 0.07, alpha: 1)
}

extension Recipes {
    static let gather: [Recipe] = [
        Recipe(id: "building-farm", cell: SpriteCell(footprint: 2, heightPx: 112), operationalFrames: 2) { kit, _ in farm(kit) },
        Recipe(id: "building-grain-farm", cell: SpriteCell(footprint: 2, heightPx: 112), operationalFrames: 2) { kit, _ in
            grainFarm(kit)
        },
        Recipe(id: "building-mine", cell: SpriteCell(footprint: 2, heightPx: 112), operationalFrames: 2) { kit, _ in mine(kit) },
        Recipe(id: "building-hop-garden", cell: SpriteCell(footprint: 2, heightPx: 128), operationalFrames: 2) { kit, _ in
            hopGarden(kit)
        },
        Recipe(id: "building-vineyard", cell: SpriteCell(footprint: 2, heightPx: 128), operationalFrames: 2) { kit, _ in
            vineyard(kit)
        },
        Recipe(id: "building-tea-garden", cell: SpriteCell(footprint: 2, heightPx: 112), operationalFrames: 2) { kit, _ in
            teaGarden(kit)
        },
        Recipe(id: "building-coffee-grove", cell: SpriteCell(footprint: 2, heightPx: 128), operationalFrames: 2) { kit, _ in
            coffeeGrove(kit)
        },
        Recipe(id: "building-sheep-farm", cell: SpriteCell(footprint: 2, heightPx: 112), operationalFrames: 2) { kit, _ in
            sheepFarm(kit)
        }
    ]

    /// Cabbage beds in dark soil and a small thatched barn.
    static func farm(_ kit: Builder) {
        kit.ground(SCNVector3(0.4, 0, 3.6), SCNVector3(7.6, 0, 7.6), .paint(Palette.soil))
        kit.hut(SCNVector3(0.8, 0, 0.8), SCNVector3(4.6, 0, 3.2), walls: .planks, roof: .thatch)
        kit.rows(SCNVector3(0.8, 0, 4.0), SCNVector3(7.4, 0, 7.4), rowStep: 0.85, plantStep: 0.7) { kit, at in
            kit.add(SCNSphere(radius: 0.26), Finish.paint(Palette.cabbage).material(), at: at + SCNVector3(0, 0.16, 0))
        }
        kit.crate(at: SCNVector3(5.4, 0, 2.2))
        kit.barrel(at: SCNVector3(6.3, 0, 1.6))
    }

    /// Ripe wheat in strips behind a fence, with a timber barn.
    static func grainFarm(_ kit: Builder) {
        kit.hut(SCNVector3(0.8, 0, 0.8), SCNVector3(5.0, 0, 3.0), walls: .planks, roof: .thatch, alongX: true)
        kit.ground(SCNVector3(0.6, 0, 3.6), SCNVector3(7.4, 0, 7.4), .paint(Palette.soil))
        // Narrow drill rows of uneven height: their sides catch light and shadow, so the crop reads as
        // standing grain rather than boards. The cut headland in front holds the sheaves.
        for (row, rowZ) in stride(from: CGFloat(3.8), to: 6.4, by: 0.3).enumerated() {
            let top = 0.6 + 0.12 * CGFloat((row * 7) % 5) / 4
            kit.block(SCNVector3(0.8, 0, rowZ), SCNVector3(7.2, top, rowZ + 0.24), .wheat, metresPerRepeat: 1.2)
        }
        kit.sheaves(along: 6.9, from: 1.4, to: 6.8)
        kit.fence(from: SCNVector3(0.5, 0, 7.6), to: SCNVector3(7.6, 0, 7.6))
        kit.fence(from: SCNVector3(7.6, 0, 3.5), to: SCNVector3(7.6, 0, 7.6))
    }

    /// A timbered adit into a rock outcrop, an ore heap and a cart on its track.
    static func mine(_ kit: Builder) {
        // An outcrop of tilted, chamfered boulders rather than stacked boxes.
        let boulders: [(centre: SCNVector3, size: SCNVector3)] = [
            (SCNVector3(2.4, 1.1, 2.2), SCNVector3(3.8, 2.2, 3.2)), (SCNVector3(5.0, 0.9, 2.6), SCNVector3(3.2, 1.8, 3.0)),
            (SCNVector3(3.0, 2.4, 1.8), SCNVector3(2.8, 1.6, 2.4)), (SCNVector3(1.4, 0.8, 3.6), SCNVector3(2.0, 1.6, 1.8)),
            (SCNVector3(6.2, 0.6, 4.0), SCNVector3(1.8, 1.2, 1.6)), (SCNVector3(4.4, 1.9, 1.4), SCNVector3(2.2, 1.4, 2.0))
        ]
        let yaws: [CGFloat] = [0.3, -0.4, 0.9, -0.2, 0.6, -0.7]
        for ((centre, size), yaw) in zip(boulders, yaws) {
            kit.add(
                SCNBox(width: size.x, height: size.y, length: size.z, chamferRadius: 0.15),
                Finish.rock.material(repeatU: 2, repeatV: 2),
                at: centre,
                euler: SCNVector3(0.08, yaw, -0.06)
            )
        }
        kit.block(SCNVector3(2.2, 0, 3.4), SCNVector3(4.9, 2.4, 4.4), .rock)
        let face = Face.south(wallZ: 4.4)
        kit.onFace(face, FaceRect(along: 3.4, y: 0.95, width: 1.6, height: 1.9), depth: 0.03, finish: .paint(Crops.opening))
        for x in [2.5, 4.3] as [CGFloat] {
            kit.block(SCNVector3(x, 0, 4.4), SCNVector3(x + 0.2, 2.1, 4.65), .timber)
        }
        kit.block(SCNVector3(2.3, 2.0, 4.4), SCNVector3(4.7, 2.3, 4.7), .timber)
        for x in [3.0, 3.8] as [CGFloat] {
            kit.block(SCNVector3(x, 0, 4.6), SCNVector3(x + 0.08, 0.06, 7.6), .timber)
        }
        kit.block(SCNVector3(2.9, 0.25, 6.0), SCNVector3(3.98, 0.9, 6.9), .planks)
        kit.block(SCNVector3(3.0, 0.9, 6.1), SCNVector3(3.88, 1.05, 6.8), .paint(Crops.ore))
        kit.add(SCNCone(topRadius: 0.1, bottomRadius: 1.2, height: 1.1), Finish.paint(Crops.ore).material(), at: SCNVector3(6.0, 0.55, 6.2))
    }

    /// Tall hop poles with climbing bines, and a half-timbered shed under a tile roof.
    static func hopGarden(_ kit: Builder) {
        kit.ground(SCNVector3(0.4, 0, 3.4), SCNVector3(7.6, 0, 7.6), .paint(Palette.soil))
        kit.hut(SCNVector3(0.8, 0, 0.8), SCNVector3(4.0, 0, 3.0), walls: .plaster, roof: .tile, framed: true)
        kit.rows(SCNVector3(1.0, 0, 4.0), SCNVector3(7.2, 0, 7.2), rowStep: 1.5, plantStep: 1.5) { kit, at in
            kit.block(at + SCNVector3(-0.05, 0, -0.05), at + SCNVector3(0.05, 3.4, 0.05), .timber)
            kit.add(
                SCNCone(topRadius: 0.12, bottomRadius: 0.38, height: 2.8),
                Finish.paint(Crops.leaf).material(),
                at: at + SCNVector3(0, 1.5, 0)
            )
            for (dx, y) in [(0.22, 1.2), (-0.2, 1.9), (0.15, 2.5)] as [(CGFloat, CGFloat)] {
                kit.add(SCNSphere(radius: 0.1), Finish.paint(Crops.hopCone).material(), at: at + SCNVector3(dx, y, 0.2))
            }
        }
        for rowZ in stride(from: CGFloat(4.75), to: 7.2, by: 1.5) { // the overhead wires along each row
            kit.block(SCNVector3(1.0, 3.3, rowZ - 0.02), SCNVector3(7.0, 3.34, rowZ + 0.02), .timber)
        }
        kit.add(SCNCylinder(radius: 0.3, height: 0.7), Finish.paint(Crops.hopCone).material(), at: SCNVector3(5.2, 0.35, 2.0))
    }

    /// Low trained vines with dark grapes, a whitewashed hut under a hipped tile roof, and a cypress.
    static func vineyard(_ kit: Builder) {
        kit.hut(SCNVector3(0.8, 0, 0.8), SCNVector3(3.8, 0, 3.2), walls: .plasterPale, roof: .tile, hip: true)
        for rowZ in stride(from: CGFloat(4.0), to: 7.4, by: 0.9) {
            kit.block(SCNVector3(0.8, 0, rowZ), SCNVector3(7.2, 0.02, rowZ + 0.3), .paint(Palette.soil))
            kit.block(SCNVector3(0.9, 0.35, rowZ + 0.02), SCNVector3(7.1, 0.95, rowZ + 0.28), .paint(Crops.leaf))
            for x in stride(from: CGFloat(1.4), to: 7.0, by: 1.1) {
                kit.add(SCNSphere(radius: 0.1), Finish.paint(Crops.grape).material(), at: SCNVector3(x, 0.45, rowZ + 0.32))
            }
        }
        kit.add(
            SCNCone(topRadius: 0, bottomRadius: 0.45, height: 3.6),
            Finish.paint(Crops.darkLeaf).material(),
            at: SCNVector3(5.4, 1.9, 1.6)
        )
        kit.barrel(at: SCNVector3(4.4, 0, 2.6))
    }

    /// Rounded tea hedges and a paper-walled hut under a slate hip roof, with a stone lantern.
    static func teaGarden(_ kit: Builder) {
        kit.hut(SCNVector3(0.8, 0, 0.8), SCNVector3(4.0, 0, 3.0), walls: .plasterPale, roof: .slate, hip: true, framed: true)
        for rowZ in stride(from: CGFloat(4.0), to: 7.4, by: 1.1) {
            kit.add(
                SCNBox(width: 6.2, height: 0.8, length: 0.8, chamferRadius: 0.38),
                Finish.paint(Crops.darkLeaf).material(),
                at: SCNVector3(4.0, 0.4, rowZ + 0.4)
            )
        }
        kit.block(SCNVector3(5.6, 0, 1.6), SCNVector3(6.0, 0.7, 2.0), .ashlar)
        kit.block(SCNVector3(5.45, 0.7, 1.45), SCNVector3(6.15, 0.95, 2.15), .ashlar)
        kit.block(SCNVector3(5.65, 0.95, 1.65), SCNVector3(5.95, 1.15, 1.95), .ashlar)
    }

    /// Glossy coffee shrubs with red cherries, a sandstone shed with a flat parapet roof, and a palm.
    static func coffeeGrove(_ kit: Builder) {
        kit.ground(SCNVector3(0.4, 0, 3.4), SCNVector3(7.6, 0, 7.6), .paint(Palette.soil))
        kit.block(SCNVector3(0.8, 0, 0.8), SCNVector3(3.8, 2.6, 3.0), .ashlar)
        kit.block(SCNVector3(0.7, 2.6, 0.7), SCNVector3(3.9, 2.9, 3.1), .ashlar)
        kit.door(Face.south(wallZ: 3.0), along: 2.2, base: 0)
        kit.rows(SCNVector3(1.0, 0, 4.0), SCNVector3(7.2, 0, 7.2), rowStep: 1.1, plantStep: 1.0) { kit, at in
            kit.add(SCNSphere(radius: 0.42), Finish.paint(Crops.darkLeaf).material(), at: at + SCNVector3(0, 0.45, 0))
            kit.add(SCNSphere(radius: 0.08), Finish.paint(Crops.cherry).material(), at: at + SCNVector3(0.3, 0.5, 0.25))
        }
        kit.palm(at: SCNVector3(5.6, 0, 1.8))
    }
}

extension Builder {
    /// A small working hut: stone plinth, walls, a door and a window on the visible faces, and a roof.
    func hut(
        _ lo: SCNVector3, _ hi: SCNVector3, walls: Finish, roof: Finish,
        hip: Bool = false, alongX: Bool = false, framed: Bool = false
    ) {
        block(SCNVector3(lo.x - 0.1, 0, lo.z - 0.1), SCNVector3(hi.x + 0.1, 0.25, hi.z + 0.1), .rubble)
        block(SCNVector3(lo.x, 0.25, lo.z), SCNVector3(hi.x, 2.3, hi.z), walls)
        let south = Face.south(wallZ: hi.z), east = Face.east(wallX: hi.x)
        if framed {
            timberFrame(south, span: lo.x ... hi.x, base: 0.25, height: 2.05, posts: 3)
            timberFrame(east, span: lo.z ... hi.z, base: 0.25, height: 2.05, posts: 2)
        }
        door(south, along: lo.x + 0.9, base: 0.25)
        window(east, along: (lo.z + hi.z) / 2, y: 1.4)
        let spec = RoofSpec(
            lo: SCNVector3(lo.x, 2.3, lo.z),
            hi: hi,
            pitchDegrees: hip ? 32 : 42,
            finish: roof,
            gableFinish: .planks,
            ridgeAlongX: alongX
        )
        if hip { hipRoof(spec) } else { gableRoof(spec) }
    }

    /// Plants on a grid over a ground rectangle: rows run along x, `rowStep` apart in rowZ.
    func rows(_ lo: SCNVector3, _ hi: SCNVector3, rowStep: CGFloat, plantStep: CGFloat, plant: (Builder, SCNVector3) -> Void) {
        for rowZ in stride(from: lo.z + rowStep / 2, to: hi.z, by: rowStep) {
            for x in stride(from: lo.x + plantStep / 2, to: hi.x, by: plantStep) {
                plant(self, SCNVector3(x, 0, rowZ))
            }
        }
    }

    /// Stooks of cut sheaves standing in a row along `rowZ`.
    func sheaves(along rowZ: CGFloat, from start: CGFloat, to end: CGFloat) {
        for x in stride(from: start, through: end, by: 1.35) {
            add(SCNCone(topRadius: 0.05, bottomRadius: 0.32, height: 0.9), Finish.wheat.material(), at: SCNVector3(x, 0.45, rowZ))
        }
    }

    /// A date palm: a leaning ringed trunk and drooping fronds.
    func palm(at base: SCNVector3) {
        add(
            SCNCylinder(radius: 0.14, height: 3.4),
            Finish.wood.material(),
            at: base + SCNVector3(0.1, 1.7, 0),
            euler: SCNVector3(0, 0, -0.06)
        )
        for index in 0 ..< 7 {
            let yaw = CGFloat(index) * 2 * .pi / 7
            add(
                SCNBox(width: 1.5, height: 0.04, length: 0.3, chamferRadius: 0),
                Finish.paint(Crops.leaf).material(),
                at: base + SCNVector3(0.2 + 0.6 * cos(yaw), 3.3, 0.6 * sin(yaw)),
                euler: SCNVector3(0, -yaw, -0.45)
            )
        }
    }
}
