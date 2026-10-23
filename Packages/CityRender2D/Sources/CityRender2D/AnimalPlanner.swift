import CityCore
import Foundation

/// Sheep and cows by the farms, hens by the houses. Drawn from the
/// snapshot, never simulated. Spec: `rendering-2_5d` / Animals graze by the
/// farms, Hens peck by the houses.
public enum AnimalPlanner {
    public enum Kind: Hashable, Sendable { case sheep, cow, hen }

    public struct Animal: Hashable, Sendable {
        public let home: EntityID
        public let slot: Int
        public let kind: Kind
        /// Position in fractional tile coordinates.
        public let col: Double
        public let row: Double
        public let walking: Bool
        public let facing: SpriteAtlas.WalkerFacing
    }

    static let herdReach = 2
    static let maxHerd = 30
    static let maxHens = 24
    static let herdMinZoom = 0.5
    static let henMinZoom = 0.75
    static let herdVisit: ClosedRange<UInt64> = 60 ... 100
    static let herdWalkTicks: UInt64 = 25
    static let henVisit: ClosedRange<UInt64> = 30 ... 50
    static let henHopTicks: UInt64 = 5

    /// The animals on screen. `isFreeGrass` says whether an animal may
    /// stand on a tile: grass, no building, no tree or rock.
    public static func animals(
        in snapshot: WorldSnapshot,
        xRange: ClosedRange<Int>,
        yRange: ClosedRange<Int>,
        reduceMotion: Bool,
        isFreeGrass: (TileCoordinate) -> Bool
    ) -> [Animal] {
        let phase = TimeOfDay(tick: snapshot.tickCount).phase
        let night = phase == .night
        let clock: UInt64? = reduceMotion || night ? nil : snapshot.tickCount
        let zoom = snapshot.camera.zoom
        let near = { (anchor: TileCoordinate, pad: Int) in
            (xRange.lowerBound - pad ... xRange.upperBound + pad).contains(anchor.x)
                && (yRange.lowerBound - pad ... yRange.upperBound + pad).contains(anchor.y)
        }
        let buildings = snapshot.buildings.values.filter { $0.state == .operational }.sorted { $0.id.raw < $1.id.raw }
        var result: [Animal] = []
        if zoom >= herdMinZoom {
            var herd: [Animal] = []
            for farm in buildings where (farm.kind == .farm || farm.kind == .grainFarm) && near(farm.anchor, herdReach) {
                let kind: Kind = farm.kind == .farm ? .sheep : .cow
                let strips = pastures(around: farm, isFreeGrass: isFreeGrass)
                guard !strips.isEmpty else { continue }
                var rng = DeterministicRNG(seed: UInt64(farm.id.raw) &* 0xA24B_AED4_963E_E407)
                let count = kind == .sheep ? 2 + Int(rng.next() % 3) : 1 + Int(rng.next() % 2)
                for slot in 0 ..< count where herd.count < maxHerd {
                    let pasture = strips[(Int(farm.id.raw) + slot) % strips.count]
                    herd.append(grazer(farm.id, slot: slot, kind: kind, pasture: pasture, clock: clock))
                }
            }
            result += herd
        }
        if zoom >= henMinZoom, !night {
            var hens: [Animal] = []
            for house in buildings where house.kind == .house && near(house.anchor, 1) {
                guard let pop = snapshot.housePopulations[house.id], pop.population > 0, pop.tier == .peasants else { continue }
                var rng = DeterministicRNG(seed: UInt64(house.id.raw) &* 0x9FB2_1C65_1E98_DF25)
                let count = 1 + Int(rng.next() % 2)
                for slot in 0 ..< count where hens.count < maxHens {
                    hens.append(hen(house, slot: slot, clock: clock))
                }
            }
            result += hens
        }
        return result
    }

    /// Free grass within `herdReach` of the farm's footprint, as up to four
    /// strips, one per side. A strip is a rectangle clear of the farm, so a
    /// walk between two of its tiles never crosses the farm.
    static func pastures(around farm: Building, isFreeGrass: (TileCoordinate) -> Bool) -> [[TileCoordinate]] {
        let footprint = BuildingCatalog.spec(for: farm.kind).footprint
        let left = farm.anchor.x - herdReach, right = farm.anchor.x + footprint.width + herdReach - 1
        let top = farm.anchor.y - herdReach, bottom = farm.anchor.y + footprint.height + herdReach - 1
        let strips: [(ClosedRange<Int>, ClosedRange<Int>)] = [
            (left ... farm.anchor.x - 1, top ... bottom),
            (farm.anchor.x + footprint.width ... right, top ... bottom),
            (left ... right, top ... farm.anchor.y - 1),
            (left ... right, farm.anchor.y + footprint.height ... bottom)
        ]
        return strips.map { cols, rows in
            rows.flatMap { row in cols.map { TileCoordinate(x: $0, y: row) } }.filter(isFreeGrass)
        }
        .filter { !$0.isEmpty }
    }

    /// A spot in a pasture tile.
    static func spot(_ pasture: [TileCoordinate], seed: UInt64) -> (col: Double, row: Double) {
        var rng = DeterministicRNG(seed: seed)
        let tile = pasture[Int(rng.next() % UInt64(pasture.count))]
        // Tile (x, y) spans x ± 0.5; keep 0.2 off its edges.
        let offset = { -0.3 + Double(rng.next() % 600) / 1000 }
        return (Double(tile.x) + offset(), Double(tile.y) + offset())
    }

    static func grazer(_ farm: EntityID, slot: Int, kind: Kind, pasture: [TileCoordinate], clock: UInt64?) -> Animal {
        let base = UInt64(farm.raw) &* 0x9E37_79B9_7F4A_7C15 ^ UInt64(slot) &* 0xBF58_476D_1CE4_E5B9
        let period = herdVisit.lowerBound + base % (herdVisit.upperBound - herdVisit.lowerBound + 1)
        let time = (clock ?? 0) &+ base % period
        let visit = time / period, into = time % period
        let target = spot(pasture, seed: base ^ visit)
        let previous = visit == 0 ? target : spot(pasture, seed: base ^ (visit - 1))
        let progress = clock == nil ? 1 : min(1, Double(into) / Double(herdWalkTicks))
        return Animal(
            home: farm, slot: slot, kind: kind,
            col: previous.col + (target.col - previous.col) * progress,
            row: previous.row + (target.row - previous.row) * progress,
            walking: progress < 1 && previous != target,
            facing: SpriteAtlas.WalkerFacing(stepX: target.col - previous.col, stepY: target.row - previous.row)
        )
    }

    /// A hen on the front edge of the house's plot: the +x or +y rim.
    static func hen(_ house: Building, slot: Int, clock: UInt64?) -> Animal {
        let footprint = BuildingCatalog.spec(for: house.kind).footprint
        let base = UInt64(house.id.raw) &* 0xD6E8_FEB8_6659_FD93 ^ UInt64(slot) &* 0x2545_F491_4F6C_DD1D
        let period = henVisit.lowerBound + base % (henVisit.upperBound - henVisit.lowerBound + 1)
        let time = (clock ?? 0) &+ base % period
        let visit = time / period, into = time % period
        func place(_ visit: UInt64) -> (col: Double, row: Double) {
            var rng = DeterministicRNG(seed: base ^ visit)
            let along = 0.3 + Double(rng.next() % 1000) / 1000 * (Double(footprint.width) - 0.6)
            let depth = Double(footprint.height) - 0.15 - Double(rng.next() % 200) / 1000
            let onRight = rng.next() % 2 == 0
            let local = onRight ? (depth, along) : (along, depth)
            return (Double(house.anchor.x) - 0.5 + local.0, Double(house.anchor.y) - 0.5 + local.1)
        }
        let target = place(visit)
        let previous = visit == 0 ? target : place(visit - 1)
        let progress = clock == nil ? 1 : min(1, Double(into) / Double(henHopTicks))
        return Animal(
            home: house.id, slot: slot, kind: .hen,
            col: previous.col + (target.col - previous.col) * progress,
            row: previous.row + (target.row - previous.row) * progress,
            walking: false,
            facing: SpriteAtlas.WalkerFacing(stepX: target.col - previous.col, stepY: target.row - previous.row)
        )
    }
}
