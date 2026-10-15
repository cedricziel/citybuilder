// Recipes for the first six buildings (Kit proof, #84). Each is parts + numbers; no geometry code lives here.
import AppKit
import SceneKit

enum Palette {
    static let shutterGreen = NSColor(red: 0.20, green: 0.32, blue: 0.24, alpha: 1)
    static let shutterRed = NSColor(red: 0.48, green: 0.18, blue: 0.12, alpha: 1)
    static let soil = NSColor(red: 0.36, green: 0.26, blue: 0.17, alpha: 1)
    static let sawdust = NSColor(red: 0.70, green: 0.56, blue: 0.36, alpha: 1)
    static let sailcloth = NSColor(red: 0.90, green: 0.84, blue: 0.70, alpha: 1)
    static let cabbage = NSColor(red: 0.38, green: 0.55, blue: 0.26, alpha: 1)
}

public enum Recipes {
    public static let all: [Recipe] = [
        Recipe(id: "building-house", cell: SpriteCell(footprint: 2, heightPx: 112), customStages: true) { kit, stage in
            housePeasant(kit, stage: peasantStage(stage))
        },
        Recipe(
            id: "building-house-tier2",
            entry: "building-house",
            cell: SpriteCell(footprint: 2, heightPx: 144),
            constructionFrames: 0
        ) { kit, _ in
            houseCitizen(kit)
        },
        Recipe(
            id: "building-house-tier3", entry: "building-house", cell: SpriteCell(footprint: 2, heightPx: 176), constructionFrames: 0
        ) { kit, _ in houseMerchant(kit) },
        Recipe(
            id: "building-town-center",
            cell: SpriteCell(footprint: 3, heightPx: 192),
            operationalFrames: 2,
            moving: MovingPart(name: "flag", build: townCenterFlag)
        ) { kit, _ in townCenter(kit) },
        Recipe(
            id: "building-sawmill",
            cell: SpriteCell(footprint: 2, heightPx: 128),
            operationalFrames: 4,
            moving: MovingPart(name: "sails", build: sawmillSails)
        ) { kit, _ in sawmill(kit) },
        Recipe(id: "building-lumberjack-hut", cell: SpriteCell(footprint: 2, heightPx: 112), operationalFrames: 2) { kit, _ in
            lumberjackHut(kit)
        },
        Recipe(id: "building-forester", cell: SpriteCell(footprint: 2, heightPx: 112), operationalFrames: 2) { kit, _ in
            forester(kit)
        }
    ]

    /// The peasant house stages itself: 0 frame, 1 walls, 2 walls and roof boards, 3 thatched and furnished.
    static func peasantStage(_ stage: Stage) -> Int {
        switch stage {
        case let .constructing(index): min(index, 2)
        case .finished: 3
        }
    }

    /// Stage 0: plinth and bare frame. 1: walls. 2: roof boards. 3: thatched, with garden and woodpile.
    static func housePeasant(_ kit: Builder, stage: Int) {
        let lo = SCNVector3(1.4, 0, 1.8), hi = SCNVector3(6.6, 0, 6.0)
        let base: CGFloat = 0.35, wallTop: CGFloat = 2.95
        kit.block(SCNVector3(lo.x - 0.1, 0, lo.z - 0.1), SCNVector3(hi.x + 0.1, base, hi.z + 0.1), .rubble)
        let south = Face.south(wallZ: hi.z), east = Face.east(wallX: hi.x)
        kit.timberFrame(south, span: lo.x ... hi.x, base: base, height: wallTop - base, posts: 4)
        kit.timberFrame(east, span: lo.z ... hi.z, base: base, height: wallTop - base, posts: 3)
        guard stage >= 1 else {
            kit.plankStack(at: SCNVector3(1.0, 0, 6.5), length: 2.4, layers: 4)
            kit.logStack(at: SCNVector3(7.0, 0, 3.0), length: 2.0, rows: 2, alongX: false)
            return
        }
        kit.block(SCNVector3(lo.x, base, lo.z), SCNVector3(hi.x, wallTop, hi.z), .plaster)
        kit.door(south, along: lo.x + 0.87, base: base)
        kit.window(south, along: lo.x + 2.6, y: 1.75, lit: false, shutters: Palette.shutterGreen)
        kit.window(south, along: lo.x + 4.33, y: 1.75, lit: true, shutters: Palette.shutterGreen)
        kit.window(east, along: lo.z + 1.05, y: 1.75, lit: false)
        kit.window(east, along: lo.z + 3.15, y: 1.75, lit: false)
        guard stage >= 2 else {
            kit.plankStack(at: SCNVector3(1.0, 0, 6.6), length: 2.4, layers: 3)
            return
        }
        let finish: Finish = stage >= 3 ? .thatch : .planks
        kit.gableRoof(RoofSpec(lo: SCNVector3(lo.x, wallTop, lo.z), hi: hi, pitchDegrees: 45, finish: finish))
        guard stage >= 3 else { return }
        kit.logStack(at: SCNVector3(hi.x + 0.3, 0, lo.z + 1.6), length: 1.6, rows: 2, alongX: false)
        kit.barrel(at: SCNVector3(lo.x + 1.9, 0, hi.z + 0.45))
        kit.ground(SCNVector3(lo.x + 2.6, 0, hi.z + 0.5), SCNVector3(hi.x, 0, 7.6), .paint(Palette.soil))
        for row in 0 ..< 2 {
            for col in 0 ..< 5 {
                kit.add(
                    SCNSphere(radius: 0.18),
                    Finish.paint(Palette.cabbage).material(),
                    at: SCNVector3(lo.x + 2.9 + CGFloat(col) * 0.5, 0.12, hi.z + 0.85 + CGFloat(row) * 0.5)
                )
            }
        }
        kit.fence(from: SCNVector3(0.4, 0, 7.6), to: SCNVector3(7.4, 0, 7.6))
        kit.fence(from: SCNVector3(0.4, 0, 1.2), to: SCNVector3(0.4, 0, 7.6))
    }

    static func houseCitizen(_ kit: Builder) {
        let lo = SCNVector3(0.9, 0, 1.2), hi = SCNVector3(7.1, 0, 6.6), jetty: CGFloat = 0.25
        kit.block(SCNVector3(lo.x - 0.1, 0, lo.z - 0.1), SCNVector3(hi.x + 0.1, 0.4, hi.z + 0.1), .rubble)
        kit.block(SCNVector3(lo.x, 0.4, lo.z), SCNVector3(hi.x, 3.0, hi.z), .ashlar)
        kit.block(SCNVector3(lo.x, 3.0, lo.z), SCNVector3(hi.x + jetty, 5.4, hi.z + jetty), .plasterPale)
        let south = Face.south(wallZ: hi.z), east = Face.east(wallX: hi.x)
        let southUp = Face.south(wallZ: hi.z + jetty), eastUp = Face.east(wallX: hi.x + jetty)
        kit.timberFrame(southUp, span: lo.x ... (hi.x + jetty), base: 3.0, height: 2.4, posts: 5)
        kit.timberFrame(eastUp, span: lo.z ... (hi.z + jetty), base: 3.0, height: 2.4, posts: 4)
        kit.door(south, along: lo.x + 1.6, base: 0.4, width: 1.2, height: 2.2)
        kit.window(south, along: lo.x + 3.4, y: 1.8, lit: true)
        kit.window(south, along: lo.x + 5.0, y: 1.8, lit: false)
        kit.window(east, along: lo.z + 1.5, y: 1.8, lit: false)
        kit.window(east, along: lo.z + 3.8, y: 1.8, lit: true)
        for index in 0 ..< 4 {
            kit.window(southUp, along: lo.x + 0.8 + CGFloat(index) * 1.61, y: 4.25, lit: index == 2, shutters: Palette.shutterRed)
        }
        for index in 0 ..< 3 {
            kit.window(eastUp, along: lo.z + 0.94 + CGFloat(index) * 1.88, y: 4.25, lit: false, shutters: Palette.shutterRed)
        }
        let ridge = kit.gableRoof(RoofSpec(
            lo: SCNVector3(lo.x, 5.4, lo.z),
            hi: SCNVector3(hi.x + jetty, 0, hi.z + jetty),
            pitchDegrees: 48,
            finish: .tile,
            gableFinish: .plasterPale
        ))
        kit.chimney(x: lo.x + 4.5, depth: (lo.z + hi.z) / 2 - 1.0, from: 5.0, to: ridge + 0.8)
        kit.porch(alongX: (lo.x + 0.8) ... (lo.x + 2.4), wallZ: hi.z, depth: 0.9, height: 2.5)
        kit.barrel(at: SCNVector3(lo.x + 2.9, 0, hi.z + 0.5))
        kit.barrel(at: SCNVector3(lo.x + 3.5, 0, hi.z + 0.7))
        kit.crate(at: SCNVector3(hi.x + 0.6, 0, hi.z - 0.8))
    }

    static func townCenter(_ kit: Builder) {
        kit.ground(SCNVector3(0.2, 0, 0.2), SCNVector3(11.8, 0, 11.8), .cobbles)
        let lo = SCNVector3(1.0, 0, 1.2), hi = SCNVector3(8.4, 0, 6.4)
        kit.block(SCNVector3(lo.x - 0.15, 0, lo.z - 0.15), SCNVector3(hi.x + 0.15, 0.5, hi.z + 0.15), .ashlar)
        kit.block(SCNVector3(lo.x, 0.5, lo.z), SCNVector3(hi.x, 4.6, hi.z), .ashlar)
        let south = Face.south(wallZ: hi.z), east = Face.east(wallX: hi.x)
        kit.door(south, along: 4.7, base: 0.5, width: 1.6, height: 2.8)
        for (index, along) in [2.0, 3.3, 6.1, 7.4].enumerated() {
            kit.window(south, along: CGFloat(along), y: 2.6, lit: index % 2 == 0)
        }
        kit.window(east, along: 3.8, y: 2.6, lit: false)
        kit.hipRoof(RoofSpec(lo: SCNVector3(lo.x, 4.6, lo.z), hi: hi, pitchDegrees: 40, finish: .slate))
        let towerLo = SCNVector3(8.4, 0, 1.2), towerHi = SCNVector3(10.8, 9.0, 3.6)
        kit.block(towerLo, towerHi, .ashlar)
        kit.window(Face.east(wallX: towerHi.x), along: 2.4, y: 6.8, lit: false)
        kit.window(Face.south(wallZ: towerHi.z), along: 9.6, y: 6.8, lit: true)
        kit.window(Face.south(wallZ: towerHi.z), along: 9.6, y: 3.2, lit: false)
        let apex = kit.hipRoof(RoofSpec(
            lo: SCNVector3(towerLo.x, towerHi.y, towerLo.z),
            hi: towerHi,
            pitchDegrees: 62,
            overhang: 0.3,
            finish: .slate
        ))
        kit.block(SCNVector3(9.57, apex - 0.2, 2.37), SCNVector3(9.63, apex + 1.6, 2.43), .timber)
        kit.well(at: SCNVector3(3.0, 0, 9.2))
        kit.stall(at: SCNVector3(6.6, 0, 9.0), cloth: Palette.shutterRed)
        kit.stall(at: SCNVector3(9.6, 0, 7.9), cloth: Palette.sailcloth)
        kit.barrel(at: SCNVector3(10.9, 0, 5.4))
        kit.barrel(at: SCNVector3(11.2, 0, 6.0))
        kit.crate(at: SCNVector3(7.8, 0, 10.7))
        kit.crate(at: SCNVector3(8.4, 0, 10.9))
    }

    /// The tower flag: furled against the pole (frame 0), then flying (frame 1).
    static func townCenterFlag(_ kit: Builder, frame: Int) {
        let tanPitch = tan(62 * CGFloat.pi / 180)
        let apex = 9.0 - 0.3 * tanPitch + 1.5 * tanPitch // the tower's hip-roof apex
        let cloth = Finish.paint(Palette.shutterRed).material()
        if frame == 0 {
            kit.add(SCNBox(width: 0.22, height: 0.8, length: 0.04, chamferRadius: 0), cloth, at: SCNVector3(9.72, apex + 1.12, 2.4))
        } else {
            kit.add(
                SCNBox(width: 0.95, height: 0.55, length: 0.03, chamferRadius: 0), cloth,
                at: SCNVector3(10.1, apex + 1.3, 2.4), euler: SCNVector3(0, 0.2, -0.05)
            )
        }
    }

    /// Merchants: ashlar shop floor, two jettied timber-framed storeys, slate hip roof, awning and goods.
    static func houseMerchant(_ kit: Builder) {
        let lo = SCNVector3(0.9, 0, 1.0), hi = SCNVector3(7.0, 0, 6.8), jetty: CGFloat = 0.22
        kit.block(SCNVector3(lo.x - 0.1, 0, lo.z - 0.1), SCNVector3(hi.x + 0.1, 0.4, hi.z + 0.1), .ashlar)
        kit.block(SCNVector3(lo.x, 0.4, lo.z), SCNVector3(hi.x, 3.2, hi.z), .ashlar)
        let south = Face.south(wallZ: hi.z), east = Face.east(wallX: hi.x)
        kit.door(south, along: lo.x + 1.4, base: 0.4, width: 1.3, height: 2.3)
        kit.window(south, along: lo.x + 3.4, y: 1.8, lit: true)
        kit.window(south, along: lo.x + 4.9, y: 1.8, lit: true)
        kit.window(east, along: lo.z + 1.6, y: 1.8, lit: false)
        kit.window(east, along: lo.z + 4.2, y: 1.8, lit: true)
        for storey in 0 ..< 2 {
            let out = jetty * CGFloat(storey + 1), base = 3.2 + CGFloat(storey) * 2.3
            kit.block(SCNVector3(lo.x, base, lo.z), SCNVector3(hi.x + out, base + 2.3, hi.z + out), .plasterPale)
            let southUp = Face.south(wallZ: hi.z + out), eastUp = Face.east(wallX: hi.x + out)
            kit.timberFrame(southUp, span: lo.x ... (hi.x + out), base: base, height: 2.3, posts: 5)
            kit.timberFrame(eastUp, span: lo.z ... (hi.z + out), base: base, height: 2.3, posts: 4)
            for index in 0 ..< 4 {
                kit.window(
                    southUp,
                    along: lo.x + 0.8 + CGFloat(index) * 1.55,
                    y: base + 1.2,
                    lit: (index + storey) % 3 == 0,
                    shutters: Palette.shutterGreen
                )
            }
            for index in 0 ..< 3 {
                kit.window(eastUp, along: lo.z + 1.0 + CGFloat(index) * 1.9, y: base + 1.2, lit: false, shutters: Palette.shutterGreen)
            }
        }
        let top = kit.hipRoof(RoofSpec(
            lo: SCNVector3(lo.x, 7.8, lo.z), hi: SCNVector3(hi.x + 2 * jetty, 0, hi.z + 2 * jetty),
            pitchDegrees: 42, overhang: 0.35, finish: .slate
        ))
        kit.chimney(x: lo.x + 1.6, depth: lo.z + 1.4, from: 7.0, to: top + 0.2)
        kit.chimney(x: hi.x - 1.2, depth: lo.z + 2.6, from: 7.0, to: top - 0.6)
        kit.stall(at: SCNVector3(lo.x + 4.2, 0, hi.z + 0.9), cloth: Palette.shutterGreen)
        kit.crate(at: SCNVector3(hi.x + 0.6, 0, hi.z - 0.6))
        kit.barrel(at: SCNVector3(hi.x + 0.5, 0, hi.z + 0.3))
    }

    static func sawmill(_ kit: Builder) {
        let lo = SCNVector3(0.8, 0, 1.6), hi = SCNVector3(6.0, 0, 5.4)
        kit.ground(SCNVector3(0.5, 0, 5.4), SCNVector3(7.4, 0, 7.7), .paint(Palette.sawdust))
        kit.block(SCNVector3(lo.x - 0.1, 0, lo.z - 0.1), SCNVector3(hi.x + 0.1, 0.3, hi.z + 0.1), .rubble)
        kit.block(SCNVector3(lo.x, 0.3, lo.z), SCNVector3(hi.x, 3.0, hi.z), .planks)
        let south = Face.south(wallZ: hi.z)
        let opening = Finish.paint(NSColor(white: 0.08, alpha: 1))
        kit.onFace(south, FaceRect(along: 2.8, y: 1.35, width: 2.8, height: 2.1), depth: 0.02, finish: opening)
        kit.add(
            SCNCylinder(radius: 0.28, height: 3.2),
            Finish.wood.material(),
            at: SCNVector3(2.8, 0.75, hi.z + 0.2),
            euler: SCNVector3(0, 0, CGFloat.pi / 2)
        )
        kit.door(Face.east(wallX: hi.x), along: 2.4, base: 0.3)
        kit.gableRoof(RoofSpec(lo: SCNVector3(lo.x, 3.0, lo.z), hi: hi, pitchDegrees: 40, finish: .thatch, gableFinish: .planks))
        kit.block(SCNVector3(hi.x, 3.9, 3.42), SCNVector3(hi.x + 0.35, 4.1, 3.58), .timber)
        kit.logStack(at: SCNVector3(2.4, 0, 6.0), length: 3.0, rows: 3, alongX: true)
        kit.plankStack(at: SCNVector3(4.6, 0, 6.2), length: 2.2, layers: 4)
    }

    /// Four sails on the east gable, rotating about x. Rendered as overlay frames (90 deg symmetry).
    static func sawmillSails(_ kit: Builder, frame: Int) {
        let hub = SCNVector3(6.45, 4.0, 3.5)
        kit.add(SCNCylinder(radius: 0.22, height: 0.35), Finish.timber.material(), at: hub, euler: SCNVector3(0, 0, CGFloat.pi / 2))
        let step = CGFloat.pi / 2 / 4
        for blade in 0 ..< 4 {
            let arm = SCNNode()
            arm.position = hub + SCNVector3(0.1, 0, 0)
            arm.eulerAngles = SCNVector3(CGFloat(blade) * .pi / 2 + CGFloat(frame) * step, 0, 0)
            let spar = SCNNode(geometry: SCNBox(width: 0.1, height: 2.9, length: 0.12, chamferRadius: 0))
            spar.geometry?.materials = [Finish.timber.material()]
            spar.position = SCNVector3(0, 1.5, 0)
            let cloth = SCNNode(geometry: SCNBox(width: 0.04, height: 2.2, length: 0.72, chamferRadius: 0))
            cloth.geometry?.materials = [Finish.paint(Palette.sailcloth).material()]
            cloth.position = SCNVector3(0.04, 1.85, 0.42)
            arm.addChildNode(spar)
            arm.addChildNode(cloth)
            kit.root.addChildNode(arm)
        }
    }

    static func lumberjackHut(_ kit: Builder) {
        let lo = SCNVector3(0.8, 0, 0.8), hi = SCNVector3(4.4, 0, 4.2)
        kit.ground(SCNVector3(0.4, 0, 4.4), SCNVector3(7.6, 0, 7.6), .paint(Palette.sawdust))
        kit.block(SCNVector3(lo.x - 0.1, 0, lo.z - 0.1), SCNVector3(hi.x + 0.1, 0.25, hi.z + 0.1), .rubble)
        kit.block(SCNVector3(lo.x, 0.25, lo.z), SCNVector3(hi.x, 2.5, hi.z), .planks)
        let south = Face.south(wallZ: hi.z)
        kit.door(south, along: 1.8, base: 0.25)
        kit.window(south, along: 3.4, y: 1.5, lit: false, shutters: Palette.shutterRed)
        kit.window(Face.east(wallX: hi.x), along: 2.5, y: 1.5, lit: true)
        kit.gableRoof(RoofSpec(
            lo: SCNVector3(lo.x, 2.5, lo.z),
            hi: hi,
            pitchDegrees: 45,
            finish: .thatch,
            gableFinish: .planks,
            ridgeAlongX: false
        ))
        kit.chimney(x: 1.6, depth: 1.6, from: 2.0, to: 5.0)
        kit.logStack(at: SCNVector3(5.0, 0, 2.5), length: 2.8, rows: 4, alongX: false)
        kit.logStack(at: SCNVector3(2.6, 0, 5.2), length: 2.6, rows: 3, alongX: true)
        kit.stump(at: SCNVector3(5.6, 0, 5.8))
        kit.add(
            SCNBox(width: 0.05, height: 0.7, length: 0.05, chamferRadius: 0),
            Finish.wood.material(),
            at: SCNVector3(5.6, 0.65, 5.8),
            euler: SCNVector3(0.5, 0, 0.3)
        )
        kit.stump(at: SCNVector3(6.8, 0, 6.9))
        kit.stump(at: SCNVector3(6.0, 0, 7.2))
        kit.fence(from: SCNVector3(7.6, 0, 0.6), to: SCNVector3(7.6, 0, 7.6))
    }

    static func forester(_ kit: Builder) {
        let lo = SCNVector3(0.8, 0, 0.8), hi = SCNVector3(4.6, 0, 3.8)
        kit.ground(SCNVector3(0.8, 0, 4.6), SCNVector3(7.2, 0, 7.4), .paint(Palette.soil))
        kit.block(SCNVector3(lo.x - 0.1, 0, lo.z - 0.1), SCNVector3(hi.x + 0.1, 0.3, hi.z + 0.1), .rubble)
        kit.block(SCNVector3(lo.x, 0.3, lo.z), SCNVector3(hi.x, 2.6, hi.z), .plaster)
        let south = Face.south(wallZ: hi.z), east = Face.east(wallX: hi.x)
        kit.timberFrame(south, span: lo.x ... hi.x, base: 0.3, height: 2.3, posts: 3)
        kit.timberFrame(east, span: lo.z ... hi.z, base: 0.3, height: 2.3, posts: 2)
        kit.door(south, along: 1.75, base: 0.3)
        kit.window(south, along: 3.65, y: 1.55, lit: false, shutters: Palette.shutterGreen)
        kit.window(east, along: 2.3, y: 1.55, lit: true)
        kit.gableRoof(RoofSpec(lo: SCNVector3(lo.x, 2.6, lo.z), hi: hi, pitchDegrees: 45, finish: .thatch))
        for row in 0 ..< 3 {
            for col in 0 ..< 6 {
                let size = 0.55 + CGFloat((row + col) % 3) * 0.2
                kit.sapling(at: SCNVector3(1.4 + CGFloat(col) * 1.0, 0, 5.2 + CGFloat(row) * 0.9), size: size)
            }
        }
        for (index, row) in [1.2, 2.4, 3.6].enumerated() {
            kit.sapling(at: SCNVector3(5.6 + CGFloat(index % 2) * 1.0, 0, CGFloat(row)), size: 1.6)
        }
        kit.barrel(at: SCNVector3(5.0, 0, 4.2))
        kit.fence(from: SCNVector3(0.6, 0, 7.6), to: SCNVector3(7.4, 0, 7.6))
        kit.fence(from: SCNVector3(7.4, 0, 4.4), to: SCNVector3(7.4, 0, 7.6))
    }
}
