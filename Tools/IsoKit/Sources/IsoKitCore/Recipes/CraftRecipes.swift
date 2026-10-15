// isokit: the craft family (workshops that turn goods into goods). Each is a working building on its
// 2 x 2 yard (the power plant on 3 x 3) with the tool of its trade in the front yard.
import AppKit
import SceneKit

enum Trade {
    static let ember = NSColor(red: 1.0, green: 0.46, blue: 0.14, alpha: 1)
    static let iron = NSColor(red: 0.22, green: 0.22, blue: 0.24, alpha: 1)
    static let flour = NSColor(red: 0.92, green: 0.88, blue: 0.78, alpha: 1)
    static let turf = NSColor(red: 0.30, green: 0.32, blue: 0.18, alpha: 1)
    static let coal = NSColor(red: 0.12, green: 0.11, blue: 0.11, alpha: 1)
    static let concrete = NSColor(red: 0.66, green: 0.65, blue: 0.62, alpha: 1)
    static let blueTile = NSColor(red: 0.18, green: 0.38, blue: 0.62, alpha: 1)
    static let awning = NSColor(red: 0.72, green: 0.26, blue: 0.18, alpha: 1)
}

extension Recipes {
    static let craft: [Recipe] = [
        Recipe(id: "building-bakery", cell: SpriteCell(footprint: 2, heightPx: 128), operationalFrames: 2) { kit, _ in bakery(kit) },
        Recipe(
            id: "building-windmill",
            cell: SpriteCell(footprint: 2, heightPx: 128),
            operationalFrames: 4,
            moving: MovingPart(name: "sails", build: windmillSails)
        ) { kit, _ in windmill(kit) },
        Recipe(id: "building-quern-house", cell: SpriteCell(footprint: 2, heightPx: 112), operationalFrames: 2) { kit, _ in
            quernHouse(kit)
        },
        Recipe(id: "building-charcoal-burner", cell: SpriteCell(footprint: 2, heightPx: 112), operationalFrames: 2) { kit, _ in
            charcoalBurner(kit)
        },
        Recipe(id: "building-smelter", cell: SpriteCell(footprint: 2, heightPx: 160), operationalFrames: 2) { kit, _ in smelter(kit) },
        Recipe(id: "building-toolsmith", cell: SpriteCell(footprint: 2, heightPx: 128), operationalFrames: 2) { kit, _ in
            toolsmith(kit)
        },
        Recipe(id: "building-brewery", cell: SpriteCell(footprint: 2, heightPx: 144), operationalFrames: 2) { kit, _ in brewery(kit) },
        Recipe(id: "building-winery", cell: SpriteCell(footprint: 2, heightPx: 128), operationalFrames: 2) { kit, _ in winery(kit) },
        Recipe(id: "building-roastery", cell: SpriteCell(footprint: 2, heightPx: 112), operationalFrames: 2) { kit, _ in roastery(kit) },
        Recipe(id: "building-steam-engine", cell: SpriteCell(footprint: 2, heightPx: 128), operationalFrames: 2) { kit, _ in
            steamEngine(kit)
        },
        Recipe(id: "building-power-plant", cell: SpriteCell(footprint: 3, heightPx: 224), operationalFrames: 2) { kit, _ in
            powerPlant(kit)
        }
    ]

    /// A half-timbered bakehouse under a tile roof, a domed brick oven on its east side, and flour sacks.
    static func bakery(_ kit: Builder) {
        kit.hut(SCNVector3(0.8, 0, 0.8), SCNVector3(4.6, 0, 4.0), walls: .plaster, roof: .tile, framed: true)
        kit.block(SCNVector3(4.6, 0, 1.6), SCNVector3(6.2, 1.0, 3.4), .brick)
        kit.add(SCNSphere(radius: 0.95), Finish.brick.material(), at: SCNVector3(5.4, 1.0, 2.5))
        kit.chimney(x: 5.4, depth: 1.9, from: 1.0, to: 4.6)
        kit.onFace(Face.east(wallX: 6.2), FaceRect(along: 2.5, y: 0.5, width: 0.7, height: 0.5), depth: 0.03, finish: .paint(Trade.ember))
        for spot in [SCNVector3(2.6, 0, 5.0), SCNVector3(3.3, 0, 5.3), SCNVector3(5.6, 0, 5.2)] {
            kit.add(SCNCylinder(radius: 0.3, height: 0.7), Finish.paint(Trade.flour).material(), at: spot + SCNVector3(0, 0.35, 0))
        }
        kit.crate(at: SCNVector3(6.4, 0, 5.8))
    }

    /// A stone tower mill under a thatched cap, its sails on the east side (a moving part).
    static func windmill(_ kit: Builder) {
        kit.add(
            SCNCone(topRadius: 1.4, bottomRadius: 1.9, height: 6.0),
            Finish.rubble.material(repeatU: 3, repeatV: 3),
            at: SCNVector3(4.0, 3.0, 4.0)
        )
        kit.add(
            SCNCone(topRadius: 0.05, bottomRadius: 1.75, height: 1.8),
            Finish.thatch.material(repeatU: 2, repeatV: 1),
            at: SCNVector3(4.0, 6.9, 4.0)
        )
        kit.door(Face.south(wallZ: 5.85), along: 4.0, base: 0)
        kit.window(Face.east(wallX: 5.75), along: 4.0, y: 3.6, lit: true)
        for spot in [SCNVector3(1.2, 0, 6.2), SCNVector3(1.8, 0, 6.8)] {
            kit.add(SCNCylinder(radius: 0.3, height: 0.7), Finish.paint(Trade.flour).material(), at: spot + SCNVector3(0, 0.35, 0))
        }
    }

    static func windmillSails(_ kit: Builder, frame: Int) {
        kit.sails(hub: SCNVector3(5.75, 5.6, 4.0), length: 3.4, frame: frame)
    }

    /// A mud-brick workshop under pale thatch, and a hand quern in the yard.
    static func quernHouse(_ kit: Builder) {
        kit.hut(SCNVector3(0.8, 0, 0.8), SCNVector3(4.2, 0, 3.4), walls: .rubble, roof: .thatch)
        kit.block(SCNVector3(4.6, 0, 4.6), SCNVector3(5.8, 0.6, 5.8), .ashlar)
        kit.add(SCNCylinder(radius: 0.55, height: 0.25), Finish.rock.material(), at: SCNVector3(5.2, 0.72, 5.2))
        kit.add(SCNCylinder(radius: 0.5, height: 0.25), Finish.rock.material(), at: SCNVector3(5.2, 0.97, 5.2))
        kit.block(SCNVector3(5.55, 1.1, 5.15), SCNVector3(5.65, 1.7, 5.25), .wood)
        for spot in [SCNVector3(2.2, 0, 4.4), SCNVector3(2.9, 0, 4.6)] {
            kit.add(SCNCylinder(radius: 0.3, height: 0.7), Finish.paint(Trade.flour).material(), at: spot + SCNVector3(0, 0.35, 0))
        }
    }

    /// A timber hut beside a turf-covered charcoal clamp and stacked logs.
    static func charcoalBurner(_ kit: Builder) {
        kit.hut(SCNVector3(0.8, 0, 0.8), SCNVector3(3.8, 0, 3.0), walls: .planks, roof: .thatch)
        kit.add(SCNCone(topRadius: 0.4, bottomRadius: 1.8, height: 1.6), Finish.paint(Trade.turf).material(), at: SCNVector3(4.8, 0.8, 5.0))
        kit.add(SCNCylinder(radius: 0.35, height: 0.05), Finish.paint(Trade.ember).material(), at: SCNVector3(4.8, 1.62, 5.0))
        kit.logStack(at: SCNVector3(1.2, 0, 5.4), length: 2.4, rows: 3, alongX: true)
        kit.add(SCNCone(topRadius: 0.1, bottomRadius: 0.8, height: 0.6), Finish.paint(Trade.coal).material(), at: SCNVector3(6.6, 0.3, 2.2))
    }

    /// A stone hall with a tall square furnace stack glowing at its base.
    static func smelter(_ kit: Builder) {
        kit.hut(SCNVector3(0.8, 0, 0.8), SCNVector3(4.4, 0, 4.0), walls: .ashlar, roof: .slate)
        kit.block(SCNVector3(4.8, 0, 1.4), SCNVector3(6.6, 6.4, 3.2), .rubble)
        kit.block(SCNVector3(4.7, 6.4, 1.3), SCNVector3(6.7, 6.7, 3.3), .rubble)
        kit.onFace(Face.south(wallZ: 3.2), FaceRect(along: 5.7, y: 0.6, width: 1.0, height: 0.9), depth: 0.03, finish: .paint(Trade.ember))
        kit.add(SCNCone(topRadius: 0.1, bottomRadius: 0.9, height: 0.7), Finish.paint(Crops.ore).material(), at: SCNVector3(2.4, 0.35, 5.6))
        kit.add(
            SCNCone(topRadius: 0.1, bottomRadius: 0.7, height: 0.5),
            Finish.paint(Trade.coal).material(),
            at: SCNVector3(5.6, 0.25, 5.8)
        )
    }

    /// A half-timbered smithy with a chimney, an anvil on a block and a quench barrel.
    static func toolsmith(_ kit: Builder) {
        kit.hut(SCNVector3(0.8, 0, 0.8), SCNVector3(4.8, 0, 3.8), walls: .plaster, roof: .tile, framed: true)
        kit.chimney(x: 1.6, depth: 1.6, from: 2.0, to: 5.2)
        kit.porch(alongX: 2.4 ... 4.6, wallZ: 3.8, depth: 1.4, height: 2.0)
        kit.block(SCNVector3(3.1, 0, 4.4), SCNVector3(3.7, 0.55, 4.9), .wood)
        kit.block(SCNVector3(3.0, 0.55, 4.5), SCNVector3(3.8, 0.8, 4.8), .paint(Trade.iron))
        kit.barrel(at: SCNVector3(5.6, 0, 4.6))
        kit.logStack(at: SCNVector3(5.4, 0, 1.2), length: 1.8, rows: 2, alongX: false)
    }

    /// A half-timbered brewhouse under a tile roof with a tall stone chimney, and casks by the door.
    static func brewery(_ kit: Builder) {
        kit.hut(SCNVector3(0.8, 0, 0.8), SCNVector3(5.2, 0, 4.0), walls: .plaster, roof: .tile, alongX: true, framed: true)
        kit.chimney(x: 4.4, depth: 1.6, from: 2.0, to: 6.0)
        for spot in [SCNVector3(2.6, 0, 4.8), SCNVector3(3.3, 0, 4.9), SCNVector3(2.95, 0.75, 4.85), SCNVector3(6.0, 0, 2.2)] {
            kit.barrel(at: spot)
        }
    }

    /// A whitewashed winery under a low hipped tile roof, a basket press, casks and a cypress.
    static func winery(_ kit: Builder) {
        kit.hut(SCNVector3(0.8, 0, 0.8), SCNVector3(4.8, 0, 3.8), walls: .plasterPale, roof: .tile, hip: true)
        kit.add(SCNCylinder(radius: 0.55, height: 0.8), Finish.wood.material(), at: SCNVector3(3.0, 0.4, 5.2))
        kit.block(SCNVector3(2.45, 0.9, 5.15), SCNVector3(3.55, 1.05, 5.25), .timber)
        kit.block(SCNVector3(2.95, 0.8, 5.15), SCNVector3(3.05, 1.6, 5.25), .timber)
        for spot in [SCNVector3(4.6, 0, 5.0), SCNVector3(5.3, 0, 5.2)] {
            kit.barrel(at: spot)
        }
        kit.add(
            SCNCone(topRadius: 0, bottomRadius: 0.45, height: 3.6),
            Finish.paint(Crops.darkLeaf).material(),
            at: SCNVector3(6.2, 1.8, 1.8)
        )
    }

    /// A sandstone roastery with a parapet roof and a blue-tiled dome, a roasting drum and coffee sacks.
    static func roastery(_ kit: Builder) {
        kit.block(SCNVector3(0.8, 0, 0.8), SCNVector3(4.6, 2.8, 3.8), .ashlar)
        kit.block(SCNVector3(0.7, 2.8, 0.7), SCNVector3(4.7, 3.1, 3.9), .ashlar)
        kit.add(SCNSphere(radius: 1.1), Finish.paint(Trade.blueTile).material(), at: SCNVector3(2.7, 3.1, 2.3))
        kit.door(Face.south(wallZ: 3.8), along: 2.0, base: 0)
        kit.window(Face.east(wallX: 4.6), along: 2.3, y: 1.6, lit: true)
        let awning = SCNBox(width: 2.2, height: 0.06, length: 1.0, chamferRadius: 0)
        kit.add(awning, Finish.paint(Trade.awning).material(), at: SCNVector3(3.5, 2.2, 4.25), euler: SCNVector3(0.3, 0, 0))
        kit.block(SCNVector3(4.6, 0, 4.8), SCNVector3(5.8, 0.6, 5.8), .brick)
        kit.add(
            SCNCylinder(radius: 0.35, height: 1.0),
            Finish.paint(Trade.iron).material(),
            at: SCNVector3(5.2, 0.95, 5.3),
            euler: SCNVector3(0, 0, CGFloat.pi / 2)
        )
        kit.palm(at: SCNVector3(6.6, 0, 2.0))
    }

    /// A brick engine house under slate, a round brick chimney, a rocking beam over a pump, and coal.
    static func steamEngine(_ kit: Builder) {
        kit.hut(SCNVector3(0.8, 0, 0.8), SCNVector3(4.4, 0, 4.4), walls: .brick, roof: .slate)
        kit.add(SCNCylinder(radius: 0.45, height: 8.0), Finish.brick.material(repeatU: 2, repeatV: 4), at: SCNVector3(5.8, 4.0, 1.8))
        kit.block(SCNVector3(4.4, 0, 2.6), SCNVector3(5.0, 3.4, 3.6), .ashlar)
        kit.add(
            SCNBox(width: 3.0, height: 0.3, length: 0.3, chamferRadius: 0),
            Finish.paint(Trade.iron).material(),
            at: SCNVector3(5.2, 3.6, 3.1),
            euler: SCNVector3(0, 0, 0.12)
        )
        kit.block(SCNVector3(6.2, 0, 2.8), SCNVector3(6.8, 1.2, 3.4), .paint(Trade.iron))
        kit.add(SCNCone(topRadius: 0.1, bottomRadius: 1.0, height: 0.8), Finish.paint(Trade.coal).material(), at: SCNVector3(5.6, 0.4, 5.8))
    }

    /// A brick hall on a concrete base under slate, two banded chimneys, and a transformer yard.
    static func powerPlant(_ kit: Builder) {
        kit.block(SCNVector3(0.6, 0, 0.6), SCNVector3(8.4, 0.5, 6.4), .paint(Trade.concrete))
        kit.block(SCNVector3(0.8, 0.5, 0.8), SCNVector3(8.2, 4.6, 6.2), .brick)
        kit.block(SCNVector3(0.7, 4.6, 0.7), SCNVector3(8.3, 4.9, 6.3), .paint(Trade.concrete))
        kit.gableRoof(RoofSpec(
            lo: SCNVector3(0.8, 4.9, 0.8),
            hi: SCNVector3(8.2, 0, 6.2),
            pitchDegrees: 25,
            finish: .slate,
            gableFinish: .brick
        ))
        let south = Face.south(wallZ: 6.2)
        for along in stride(from: CGFloat(1.8), through: 7.2, by: 1.35) {
            kit.onFace(south, FaceRect(along: along, y: 2.6, width: 0.8, height: 2.6), depth: 0.05, finish: .glass)
        }
        for x in [2.4, 6.6] as [CGFloat] {
            kit.add(SCNCylinder(radius: 0.55, height: 9.0), Finish.paint(Trade.concrete).material(), at: SCNVector3(x, 4.5, 2.0))
            kit.add(SCNCylinder(radius: 0.57, height: 0.5), Finish.paint(Trade.awning).material(), at: SCNVector3(x, 8.3, 2.0))
        }
        kit.block(SCNVector3(2.0, 0, 7.4), SCNVector3(3.2, 1.4, 8.4), .paint(Trade.iron))
        kit.block(SCNVector3(4.0, 0, 7.4), SCNVector3(5.2, 1.4, 8.4), .paint(Trade.iron))
        kit.fence(from: SCNVector3(1.4, 0, 9.0), to: SCNVector3(9.0, 0, 9.0))
    }
}

extension Builder {
    /// Four sails on an east-facing hub, turning about x by a sixteenth of a turn (π/8) per overlay
    /// frame: four frames make a quarter turn, which the four-fold symmetry repeats.
    func sails(hub: SCNVector3, length: CGFloat, frame: Int) {
        add(SCNCylinder(radius: 0.22, height: 0.35), Finish.timber.material(), at: hub, euler: SCNVector3(0, 0, CGFloat.pi / 2))
        let step = CGFloat.pi / 2 / 4
        for blade in 0 ..< 4 {
            let arm = SCNNode()
            arm.position = hub + SCNVector3(0.1, 0, 0)
            arm.eulerAngles = SCNVector3(CGFloat(blade) * .pi / 2 + CGFloat(frame) * step, 0, 0)
            let spar = SCNNode(geometry: SCNBox(width: 0.1, height: length, length: 0.12, chamferRadius: 0))
            spar.geometry?.materials = [Finish.timber.material()]
            spar.position = SCNVector3(0, length / 2 + 0.05, 0)
            let cloth = SCNNode(geometry: SCNBox(width: 0.04, height: length * 0.76, length: 0.72, chamferRadius: 0))
            cloth.geometry?.materials = [Finish.paint(Palette.sailcloth).material()]
            cloth.position = SCNVector3(0.04, length * 0.64, 0.42)
            arm.addChildNode(spar)
            arm.addChildNode(cloth)
            root.addChildNode(arm)
        }
    }
}
