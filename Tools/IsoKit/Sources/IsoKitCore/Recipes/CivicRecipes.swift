// isokit: the civic family (storage and town buildings) and the culture looks of the warehouse
// and library. Most stand on 3 x 3 yards; front yards carry the props the camera sees.
import AppKit
import SceneKit

enum Civic {
    static let lacquer = NSColor(red: 0.62, green: 0.14, blue: 0.10, alpha: 1)
    static let bronze = NSColor(red: 0.46, green: 0.34, blue: 0.18, alpha: 1)
    static let travertine = NSColor(red: 0.86, green: 0.82, blue: 0.72, alpha: 1)
    static let gravel = NSColor(red: 0.52, green: 0.52, blue: 0.50, alpha: 1) // cool, so the warm sun leaves it grey
    static let pond = NSColor(red: 0.20, green: 0.36, blue: 0.40, alpha: 1)
    static let ochre = NSColor(red: 0.80, green: 0.58, blue: 0.32, alpha: 1)
    static let gold = NSColor(red: 0.82, green: 0.64, blue: 0.22, alpha: 1)
}

extension Recipes {
    static let civic: [Recipe] = [
        Recipe(id: "building-warehouse", cell: SpriteCell(footprint: 3, heightPx: 160)) { kit, _ in warehouse(kit) },
        Recipe(id: "building-library", cell: SpriteCell(footprint: 2, heightPx: 128), operationalFrames: 2) { kit, _ in library(kit) },
        Recipe(id: "building-mead-hall", cell: SpriteCell(footprint: 3, heightPx: 176), operationalFrames: 2) { kit, _ in meadHall(kit) },
        Recipe(id: "building-forum", cell: SpriteCell(footprint: 3, heightPx: 160), operationalFrames: 2) { kit, _ in forum(kit) },
        Recipe(id: "building-tea-house", cell: SpriteCell(footprint: 2, heightPx: 128), operationalFrames: 2) { kit, _ in teaHouse(kit) },
        Recipe(id: "building-temple-garden", cell: SpriteCell(footprint: 3, heightPx: 160), operationalFrames: 2) { kit, _ in
            templeGarden(kit)
        },
        Recipe(id: "building-caravanserai", cell: SpriteCell(footprint: 3, heightPx: 176), operationalFrames: 2) { kit, _ in
            caravanserai(kit)
        },
        Recipe(id: "building-monument", cell: SpriteCell(footprint: 3, heightPx: 160), operationalFrames: 2) { kit, _ in monument(kit) },
        Recipe(id: "building-guild-hall", cell: SpriteCell(footprint: 3, heightPx: 224), operationalFrames: 2) { kit, _ in guildHall(kit) },
        Recipe(id: "building-gallery", cell: SpriteCell(footprint: 2, heightPx: 144), operationalFrames: 2) { kit, _ in gallery(kit) },
        Recipe(id: "building-warehouse-east-asian", cell: SpriteCell(footprint: 3, heightPx: 160), constructionFrames: 0) { kit, _ in
            warehouseEastAsian(kit)
        },
        Recipe(id: "building-warehouse-mediterranean", cell: SpriteCell(footprint: 3, heightPx: 160), constructionFrames: 0) { kit, _ in
            warehouseMediterranean(kit)
        },
        Recipe(id: "building-warehouse-middle-eastern", cell: SpriteCell(footprint: 3, heightPx: 160), constructionFrames: 0) { kit, _ in
            warehouseMiddleEastern(kit)
        },
        Recipe(
            id: "building-library-east-asian", cell: SpriteCell(footprint: 2, heightPx: 112), constructionFrames: 0, operationalFrames: 2
        ) { kit, _ in libraryEastAsian(kit) },
        Recipe(
            id: "building-library-mediterranean", cell: SpriteCell(footprint: 2, heightPx: 128), constructionFrames: 0, operationalFrames: 2
        ) { kit, _ in libraryMediterranean(kit) },
        Recipe(
            id: "building-library-middle-eastern", cell: SpriteCell(footprint: 2, heightPx: 128), constructionFrames: 0,
            operationalFrames: 2
        ) { kit, _ in libraryMiddleEastern(kit) }
    ]

    /// A long stone-and-timber storehouse under slate, double cargo doors, and crates and barrels.
    static func warehouse(_ kit: Builder) {
        kit.hall(SCNVector3(1.0, 0, 1.2), SCNVector3(10.6, 0, 6.6), walls: .rubble, roof: .slate, wallHeight: 3.2)
        kit.timberFrame(Face.south(wallZ: 6.6), span: 1.0 ... 10.6, base: 1.8, height: 1.4, posts: 7)
        kit.door(Face.south(wallZ: 6.6), along: 4.0, base: 0.25, width: 2.0, height: 2.4)
        kit.door(Face.south(wallZ: 6.6), along: 7.6, base: 0.25, width: 2.0, height: 2.4)
        kit.cargo(at: SCNVector3(2.0, 0, 8.4))
        kit.cargo(at: SCNVector3(9.0, 0, 8.6))
    }

    /// A stone hall with tall narrow windows under slate, and a small bell turret on the ridge.
    static func library(_ kit: Builder) {
        kit.hall(SCNVector3(0.8, 0, 1.0), SCNVector3(6.6, 0, 5.4), walls: .ashlar, roof: .slate, wallHeight: 3.6)
        for along in [2.0, 3.7, 5.4] as [CGFloat] {
            kit.onFace(Face.south(wallZ: 5.4), FaceRect(along: along, y: 2.2, width: 0.6, height: 1.8), depth: 0.06, finish: .glass)
        }
        kit.block(SCNVector3(5.6, 5.4, 2.9), SCNVector3(6.4, 7.0, 3.6), .ashlar)
        kit.add(SCNPyramid(width: 1.0, height: 0.9, length: 0.9), Finish.slate.material(), at: SCNVector3(6.0, 7.0, 3.25))
    }

    /// A long log hall under a steep plank roof with crossed gable boards, a carved door and barrels.
    static func meadHall(_ kit: Builder) {
        kit.hall(SCNVector3(1.0, 0, 1.6), SCNVector3(10.6, 0, 6.6), walls: .planks, roof: .planks, wallHeight: 2.6, pitch: 52)
        for x in [0.9, 10.7] as [CGFloat] {
            kit.block(SCNVector3(x - 0.08, 5.6, 3.9), SCNVector3(x + 0.08, 7.4, 4.3), .timber)
        }
        kit.door(Face.south(wallZ: 6.6), along: 5.8, base: 0.25, width: 1.4, height: 2.0)
        for x in [4.85, 6.75] as [CGFloat] {
            kit.block(SCNVector3(x - 0.15, 0, 6.6), SCNVector3(x + 0.15, 2.4, 6.9), .paint(Civic.lacquer))
        }
        kit.block(SCNVector3(2.0, 0.4, 7.6), SCNVector3(4.0, 0.5, 8.0), .wood)
        kit.barrel(at: SCNVector3(8.2, 0, 7.8))
        kit.barrel(at: SCNVector3(8.9, 0, 8.0))
    }

    /// A paved square framed by colonnades on its two back sides, a statue, a fountain and a cypress.
    static func forum(_ kit: Builder) {
        kit.ground(SCNVector3(0.4, 0, 0.4), SCNVector3(11.6, 0, 11.6), .cobbles)
        kit.colonnade(from: SCNVector3(1.0, 0, 1.0), to: SCNVector3(11.0, 0, 1.0))
        kit.colonnade(from: SCNVector3(1.0, 0, 1.0), to: SCNVector3(1.0, 0, 11.0))
        kit.block(SCNVector3(6.0, 0, 6.0), SCNVector3(7.2, 1.4, 7.2), .paint(Civic.travertine))
        kit.add(SCNCylinder(radius: 0.28, height: 1.8), Finish.paint(Civic.bronze).material(), at: SCNVector3(6.6, 2.3, 6.6))
        kit.add(
            SCNTube(innerRadius: 0.8, outerRadius: 1.0, height: 0.5),
            Finish.paint(Civic.travertine).material(),
            at: SCNVector3(9.0, 0.25, 9.4)
        )
        kit.add(SCNCylinder(radius: 0.8, height: 0.4), Finish.paint(Civic.pond).material(), at: SCNVector3(9.0, 0.2, 9.4))
        kit.add(
            SCNCone(topRadius: 0, bottomRadius: 0.5, height: 4.0),
            Finish.paint(Crops.darkLeaf).material(),
            at: SCNVector3(3.4, 2.0, 9.4)
        )
    }

    /// A post-and-beam pavilion on a stone plinth with a deck, red posts under a wide dark roof, and lanterns.
    static func teaHouse(_ kit: Builder) {
        kit.block(SCNVector3(0.8, 0, 0.8), SCNVector3(6.8, 0.5, 6.0), .ashlar)
        kit.block(SCNVector3(1.0, 0.5, 1.0), SCNVector3(6.6, 0.6, 5.8), .planks)
        kit.block(SCNVector3(1.8, 0.6, 1.4), SCNVector3(5.8, 2.8, 4.4), .plasterPale)
        for x in [1.2, 6.4] as [CGFloat] {
            for depth in [1.2, 5.6] as [CGFloat] {
                kit.block(SCNVector3(x - 0.1, 0.6, depth - 0.1), SCNVector3(x + 0.1, 3.0, depth + 0.1), .paint(Civic.lacquer))
            }
        }
        kit.hipRoof(RoofSpec(lo: SCNVector3(0.8, 3.0, 0.8), hi: SCNVector3(6.8, 0, 6.0), pitchDegrees: 28, overhang: 0.7, finish: .slate))
        for x in [2.4, 5.2] as [CGFloat] {
            kit.add(SCNSphere(radius: 0.22), Finish.paint(Civic.lacquer).material(), at: SCNVector3(x, 2.6, 6.2))
        }
    }

    /// Raked gravel round a small shrine under a dark roof, a red gate, a stone lantern, a pond and a pine.
    static func templeGarden(_ kit: Builder) {
        kit.ground(SCNVector3(0.4, 0, 0.4), SCNVector3(11.6, 0, 11.6), .paint(Civic.gravel))
        kit.block(SCNVector3(1.2, 0, 1.2), SCNVector3(5.6, 0.7, 5.2), .ashlar)
        kit.block(SCNVector3(1.8, 0.7, 1.8), SCNVector3(5.0, 3.0, 4.6), .planks)
        kit.hipRoof(RoofSpec(lo: SCNVector3(1.8, 3.0, 1.8), hi: SCNVector3(5.0, 0, 4.6), pitchDegrees: 30, overhang: 0.6, finish: .slate))
        kit.torii(at: SCNVector3(6.0, 0, 9.8))
        kit.add(SCNCylinder(radius: 1.4, height: 0.1), Finish.paint(Civic.pond).material(), at: SCNVector3(9.0, 0.05, 4.0))
        kit.block(SCNVector3(9.4, 0, 8.4), SCNVector3(9.8, 1.6, 8.8), .ashlar)
        kit.block(SCNVector3(9.2, 1.6, 8.2), SCNVector3(10.0, 1.9, 9.0), .ashlar)
        kit.add(
            SCNCone(topRadius: 0.2, bottomRadius: 1.0, height: 1.6),
            Finish.paint(Crops.darkLeaf).material(),
            at: SCNVector3(2.8, 1.8, 8.6)
        )
        kit.block(SCNVector3(2.7, 0, 8.5), SCNVector3(2.9, 1.0, 8.7), .timber)
    }

    /// A sandstone courtyard: arcaded wings on the back sides, a blue dome, a gate in the low front wall, a palm.
    static func caravanserai(_ kit: Builder) {
        kit.ground(SCNVector3(0.6, 0, 0.6), SCNVector3(11.4, 0, 11.4), .paint(Civic.gravel))
        kit.block(SCNVector3(0.8, 0, 0.8), SCNVector3(11.2, 5.0, 3.6), .ashlar)
        kit.block(SCNVector3(0.8, 0, 3.6), SCNVector3(3.6, 5.0, 11.2), .ashlar)
        kit.arcade(Face.south(wallZ: 3.6), from: 4.4, to: 10.8, base: 0)
        kit.arcade(Face.east(wallX: 3.6), from: 4.4, to: 10.8, base: 0)
        kit.add(SCNSphere(radius: 1.3), Finish.paint(Trade.blueTile).material(), at: SCNVector3(2.2, 5.2, 2.2))
        kit.block(SCNVector3(3.6, 0, 10.8), SCNVector3(11.2, 1.6, 11.2), .ashlar)
        kit.block(SCNVector3(6.6, 0, 10.7), SCNVector3(8.4, 3.4, 11.3), .ashlar)
        kit.onFace(
            Face.south(wallZ: 11.3),
            FaceRect(along: 7.5, y: 1.2, width: 1.1, height: 2.4),
            depth: 0.03,
            finish: .paint(Crops.opening)
        )
        kit.palm(at: SCNVector3(9.6, 0, 6.0))
        kit.crate(at: SCNVector3(5.4, 0, 6.2))
    }

    /// A stepped podium carrying a six-column temple front under a tile pediment, and a bronze brazier.
    static func monument(_ kit: Builder) {
        for (step, inset) in [0.6, 1.2, 1.8].enumerated() {
            kit.block(
                SCNVector3(inset, CGFloat(step) * 0.5, inset),
                SCNVector3(12 - inset, CGFloat(step + 1) * 0.5, 12 - inset),
                .paint(Civic.travertine)
            )
        }
        kit.block(SCNVector3(2.4, 1.5, 2.2), SCNVector3(9.6, 5.5, 6.4), .paint(Civic.travertine))
        for index in 0 ..< 6 {
            let x = 2.8 + CGFloat(index) * 1.28
            kit.add(SCNCylinder(radius: 0.32, height: 4.0), Finish.paint(Civic.travertine).material(), at: SCNVector3(x, 3.5, 8.6))
        }
        kit.block(SCNVector3(2.2, 5.5, 2.0), SCNVector3(9.8, 6.0, 9.0), .paint(Civic.travertine))
        kit.gableRoof(RoofSpec(
            lo: SCNVector3(2.2, 6.0, 2.0),
            hi: SCNVector3(9.8, 0, 9.0),
            pitchDegrees: 18,
            overhang: 0.2,
            finish: .tile,
            gableFinish: .plasterPale,
            ridgeAlongX: false
        ))
        kit.add(SCNCylinder(radius: 0.4, height: 0.8), Finish.paint(Civic.bronze).material(), at: SCNVector3(9.6, 1.9, 10.4))
    }

    /// A stone ground floor under two half-timbered storeys and a steep tile roof with a bell turret.
    static func guildHall(_ kit: Builder) {
        let lo = SCNVector3(1.2, 0, 1.2), hi = SCNVector3(9.6, 0, 7.4)
        kit.block(SCNVector3(lo.x, 0, lo.z), SCNVector3(hi.x, 2.6, hi.z), .ashlar)
        kit.block(SCNVector3(lo.x - 0.15, 2.6, lo.z - 0.15), SCNVector3(hi.x + 0.15, 6.4, hi.z + 0.15), .plaster)
        let south = Face.south(wallZ: hi.z + 0.15), east = Face.east(wallX: hi.x + 0.15)
        kit.timberFrame(south, span: lo.x ... hi.x, base: 2.6, height: 3.8, posts: 6)
        kit.timberFrame(east, span: lo.z ... hi.z, base: 2.6, height: 3.8, posts: 4)
        for along in [3.0, 5.4, 7.8] as [CGFloat] {
            kit.window(south, along: along, y: 4.4)
        }
        kit.door(Face.south(wallZ: hi.z), along: 5.4, base: 0, width: 1.6, height: 2.2)
        kit.gableRoof(RoofSpec(lo: SCNVector3(lo.x, 6.4, lo.z), hi: hi, pitchDegrees: 52, finish: .tile, gableFinish: .plaster))
        kit.block(SCNVector3(5.0, 10.0, 4.0), SCNVector3(5.8, 11.4, 4.6), .timber)
        kit.add(SCNPyramid(width: 1.1, height: 1.0, length: 0.9), Finish.slate.material(), at: SCNVector3(5.4, 11.4, 4.3))
        kit.block(SCNVector3(9.0, 3.0, 7.6), SCNVector3(9.08, 3.06, 8.6), .paint(Trade.iron))
        kit.block(SCNVector3(8.75, 2.3, 8.5), SCNVector3(9.35, 2.95, 8.56), .paint(Civic.lacquer))
    }

    /// An ochre stuccoed palazzo over a three-arched stone arcade, a cornice and a red banner on the roof.
    static func gallery(_ kit: Builder) {
        let lo = SCNVector3(0.8, 0, 0.8), hi = SCNVector3(7.2, 0, 6.4)
        kit.block(SCNVector3(lo.x, 0, lo.z), SCNVector3(hi.x, 3.0, hi.z), .ashlar)
        kit.arcade(Face.south(wallZ: hi.z), from: lo.x + 0.4, to: hi.x - 0.4, base: 0)
        kit.block(SCNVector3(lo.x, 3.0, lo.z), SCNVector3(hi.x, 6.4, hi.z), .paint(Civic.ochre))
        for along in [2.0, 6.0] as [CGFloat] {
            kit.window(Face.south(wallZ: hi.z), along: along, y: 4.7)
        }
        kit.onFace(
            Face.south(wallZ: hi.z),
            FaceRect(along: 4.0, y: 4.7, width: 0.9, height: 1.6),
            depth: 0.04,
            finish: .paint(Civic.travertine)
        )
        kit.block(SCNVector3(lo.x - 0.25, 6.4, lo.z - 0.25), SCNVector3(hi.x + 0.25, 6.8, hi.z + 0.25), .paint(Civic.travertine))
        let roof = RoofSpec(
            lo: SCNVector3(lo.x + 0.2, 6.8, lo.z + 0.2),
            hi: SCNVector3(hi.x - 0.2, 0, hi.z - 0.2),
            pitchDegrees: 18,
            overhang: 0,
            finish: .tile
        )
        kit.hipRoof(roof)
        kit.block(SCNVector3(6.0, 7.4, 2.0), SCNVector3(6.08, 9.6, 2.08), .timber)
        kit.block(SCNVector3(6.08, 8.4, 2.0), SCNVector3(6.9, 9.4, 2.04), .paint(Civic.lacquer))
    }

    /// Kura: thick white walls over a dark plinth, heavy doors, a long flared slate roof, rice bales.
    static func warehouseEastAsian(_ kit: Builder) {
        kit.block(SCNVector3(1.0, 0, 1.2), SCNVector3(10.6, 1.0, 6.6), .slate)
        kit.hall(SCNVector3(1.0, 1.0, 1.2), SCNVector3(10.6, 0, 6.6), walls: .plasterPale, roof: .slate, wallHeight: 2.6, plinth: false)
        kit.door(Face.south(wallZ: 6.6), along: 5.8, base: 0, width: 1.8, height: 2.6)
        for x in [2.4, 3.2, 8.6] as [CGFloat] {
            kit.add(
                SCNCylinder(radius: 0.35, height: 0.8),
                Finish.thatch.material(),
                at: SCNVector3(x, 0.35, 8.2),
                euler: SCNVector3(0, 0, CGFloat.pi / 2)
            )
        }
    }

    /// A whitewashed storehouse under a low hipped tile roof, arched cargo doors and amphorae.
    static func warehouseMediterranean(_ kit: Builder) {
        kit.hall(SCNVector3(1.0, 0, 1.2), SCNVector3(10.6, 0, 6.6), walls: .plasterPale, roof: .tile, wallHeight: 3.0, hip: true)
        kit.archDoor(Face.south(wallZ: 6.6), along: 4.0, width: 1.8, height: 2.4)
        kit.archDoor(Face.south(wallZ: 6.6), along: 7.6, width: 1.8, height: 2.4)
        kit.amphorae(at: SCNVector3(2.4, 0, 8.4))
        kit.crate(at: SCNVector3(9.0, 0, 8.6))
    }

    /// A sandstone store with a parapet roof, a tall arched gate framed in blue tile, an awning and a palm.
    static func warehouseMiddleEastern(_ kit: Builder) {
        kit.block(SCNVector3(1.0, 0, 1.2), SCNVector3(10.6, 3.4, 6.6), .ashlar)
        kit.block(SCNVector3(0.9, 3.4, 1.1), SCNVector3(10.7, 3.8, 6.7), .ashlar)
        kit.onFace(
            Face.south(wallZ: 6.6),
            FaceRect(along: 5.8, y: 1.6, width: 2.4, height: 3.2),
            depth: 0.04,
            finish: .paint(Trade.blueTile)
        )
        kit.archDoor(Face.south(wallZ: 6.66), along: 5.8, width: 1.8, height: 2.8)
        kit.add(
            SCNBox(width: 2.4, height: 0.06, length: 1.0, chamferRadius: 0),
            Finish.paint(Trade.awning).material(),
            at: SCNVector3(2.8, 2.4, 7.1),
            euler: SCNVector3(0.3, 0, 0)
        )
        kit.palm(at: SCNVector3(9.6, 0, 8.6))
        kit.cargo(at: SCNVector3(2.2, 0, 8.6))
    }

    /// A long hall on a stepped plinth with red posts and one big sweeping slate roof.
    static func libraryEastAsian(_ kit: Builder) {
        kit.block(SCNVector3(0.6, 0, 0.8), SCNVector3(7.0, 0.7, 5.8), .ashlar)
        kit.block(SCNVector3(1.2, 0.7, 1.4), SCNVector3(6.4, 3.0, 4.8), .plasterPale)
        for along in stride(from: CGFloat(1.4), through: 6.3, by: 1.3) {
            kit.block(SCNVector3(along - 0.1, 0.7, 5.0), SCNVector3(along + 0.1, 3.2, 5.2), .paint(Civic.lacquer))
        }
        kit.hipRoof(RoofSpec(lo: SCNVector3(0.6, 3.2, 0.8), hi: SCNVector3(7.0, 0, 5.8), pitchDegrees: 32, overhang: 0.7, finish: .slate))
    }

    /// A whitewashed hall under a low tile roof, tall arched windows, and a bell gable over the east end.
    static func libraryMediterranean(_ kit: Builder) {
        kit.hall(SCNVector3(0.8, 0, 1.0), SCNVector3(6.6, 0, 5.4), walls: .plasterPale, roof: .tile, wallHeight: 3.6, pitch: 24)
        for along in [2.0, 3.7, 5.4] as [CGFloat] {
            kit.archDoor(Face.south(wallZ: 5.4), along: along, width: 0.6, height: 1.6, base: 1.4, finish: .glass)
        }
        kit.block(SCNVector3(6.4, 3.6, 2.4), SCNVector3(6.8, 6.6, 4.0), .plasterPale)
        kit.onFace(Face.east(wallX: 6.8), FaceRect(along: 3.2, y: 5.6, width: 0.6, height: 0.7), depth: 0.03, finish: .paint(Crops.opening))
    }

    /// A sandstone cube with a parapet roof, tall arched windows framed in blue, and a white dome on a drum.
    static func libraryMiddleEastern(_ kit: Builder) {
        kit.block(SCNVector3(1.0, 0, 1.0), SCNVector3(6.6, 4.0, 5.6), .ashlar)
        kit.block(SCNVector3(0.9, 4.0, 0.9), SCNVector3(6.7, 4.4, 5.7), .ashlar)
        for along in [2.4, 5.2] as [CGFloat] {
            kit.onFace(
                Face.south(wallZ: 5.6),
                FaceRect(along: along, y: 2.0, width: 1.2, height: 2.6),
                depth: 0.03,
                finish: .paint(Trade.blueTile)
            )
            kit.archDoor(Face.south(wallZ: 5.64), along: along, width: 0.7, height: 2.0, base: 1.0, finish: .glass)
        }
        kit.add(SCNCylinder(radius: 1.3, height: 0.8), Finish.paint(Trade.blueTile).material(), at: SCNVector3(3.8, 4.8, 3.3))
        kit.add(SCNSphere(radius: 1.3), Finish.plasterPale.material(), at: SCNVector3(3.8, 5.2, 3.3))
    }
}

extension Builder {
    /// A long hall: plinth, walls of `wallHeight`, door-less, under a gable (or hip) roof along x.
    func hall(
        _ lo: SCNVector3, _ hi: SCNVector3, walls: Finish, roof: Finish, wallHeight: CGFloat,
        pitch: CGFloat = 38, hip: Bool = false, plinth: Bool = true
    ) {
        if plinth {
            block(SCNVector3(lo.x - 0.1, lo.y, lo.z - 0.1), SCNVector3(hi.x + 0.1, lo.y + 0.25, hi.z + 0.1), .rubble)
        }
        let base = lo.y + (plinth ? 0.25 : 0)
        block(SCNVector3(lo.x, base, lo.z), SCNVector3(hi.x, base + wallHeight, hi.z), walls)
        let spec = RoofSpec(lo: SCNVector3(lo.x, base + wallHeight, lo.z), hi: hi, pitchDegrees: pitch, finish: roof, gableFinish: walls)
        if hip { hipRoof(spec) } else { gableRoof(spec) }
    }

    /// A door or window with a round head: a slab and a half-disc above it.
    func archDoor(_ face: Face, along: CGFloat, width: CGFloat, height: CGFloat, base: CGFloat = 0, finish: Finish = .planks) {
        onFace(
            face,
            FaceRect(along: along, y: base + (height - width / 2) / 2, width: width, height: height - width / 2),
            depth: 0.06,
            finish: finish
        )
        let head = SCNCylinder(radius: width / 2, height: 0.06)
        let centre = face.point(along: along, y: base + height - width / 2, out: 0.06)
        let facing = if case .south = face { SCNVector3(CGFloat.pi / 2, 0, 0) } else { SCNVector3(0, 0, CGFloat.pi / 2) }
        add(head, finish.material(), at: centre, euler: facing)
    }

    /// Arches along a face between `from` and `to`, about 1.6 m apart.
    func arcade(_ face: Face, from start: CGFloat, to end: CGFloat, base: CGFloat) {
        let count = max(Int((end - start) / 1.6), 1)
        let step = (end - start) / CGFloat(count)
        for index in 0 ..< count {
            archDoor(
                face,
                along: start + step * (CGFloat(index) + 0.5),
                width: step * 0.62,
                height: 2.4,
                base: base,
                finish: .paint(Crops.opening)
            )
        }
    }

    /// A colonnade: columns along a line under a tiled lean-to roof.
    func colonnade(from start: SCNVector3, to end: SCNVector3) {
        let delta = end - start
        let count = max(Int(delta.length / 1.4), 1)
        for index in 0 ... count {
            let at = start + delta * (CGFloat(index) / CGFloat(count))
            add(SCNCylinder(radius: 0.22, height: 3.0), Finish.paint(Civic.travertine).material(), at: at + SCNVector3(0, 1.5, 0))
        }
        let along = delta.x != 0
        let lo = SCNVector3(min(start.x, end.x) - 0.5, 3.0, min(start.z, end.z) - 0.5)
        let hi = SCNVector3(max(start.x, end.x) + (along ? 0.5 : 1.0), 3.3, max(start.z, end.z) + (along ? 1.0 : 0.5))
        block(lo, hi, .tile)
    }

    /// A red torii gate facing south.
    func torii(at base: SCNVector3) {
        for dx in [-1.0, 1.0] as [CGFloat] {
            add(SCNCylinder(radius: 0.14, height: 2.6), Finish.paint(Civic.lacquer).material(), at: base + SCNVector3(dx, 1.3, 0))
        }
        block(base + SCNVector3(-1.6, 2.6, -0.15), base + SCNVector3(1.6, 2.85, 0.15), .paint(Civic.lacquer))
        block(base + SCNVector3(-1.2, 2.05, -0.1), base + SCNVector3(1.2, 2.2, 0.1), .paint(Civic.lacquer))
    }

    /// Crates and barrels of stored goods.
    func cargo(at base: SCNVector3) {
        crate(at: base)
        crate(at: base + SCNVector3(0.7, 0, 0.1))
        crate(at: base + SCNVector3(0.35, 0.55, 0.05))
        barrel(at: base + SCNVector3(1.5, 0, 0.3))
    }

    func amphorae(at base: SCNVector3) {
        for offset in [SCNVector3(0, 0, 0), SCNVector3(0.55, 0, 0.2), SCNVector3(1.1, 0, 0)] {
            add(SCNCapsule(capRadius: 0.22, height: 0.9), Finish.paint(Trade.awning).material(), at: base + offset + SCNVector3(0, 0.45, 0))
        }
    }
}
