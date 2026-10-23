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

    /// Where animals may stand.
    public struct Ground {
        /// Grass with no building, tree or rock: where herds graze.
        public let isFreeGrass: (TileCoordinate) -> Bool
        /// Free grass or road: where hens peck.
        public let isYard: (TileCoordinate) -> Bool

        public init(isFreeGrass: @escaping (TileCoordinate) -> Bool, isYard: @escaping (TileCoordinate) -> Bool) {
            self.isFreeGrass = isFreeGrass
            self.isYard = isYard
        }
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
    /// Night as tick offsets within a day: it begins at fraction 0.85 and
    /// ends at 0.2 (`TimeOfDay.phase`), counted from `TimeOfDay.startFraction`.
    static let nightBegins = UInt64(((0.85 - TimeOfDay.startFraction) * Double(TimeOfDay.ticksPerDay)).rounded())
    static let nightEnds = UInt64(((1.2 - TimeOfDay.startFraction) * Double(TimeOfDay.ticksPerDay)).rounded())

    /// Daylight ticks before `tick`: the clock animals move by. It stops
    /// while night lasts, so they hold where they stood at dusk and carry
    /// on from there at dawn.
    public static func dayClock(tick: UInt64) -> UInt64 {
        let day = TimeOfDay.ticksPerDay, nightLength = nightEnds - nightBegins
        let into = tick % day
        let tonight = into > nightBegins ? min(into, nightEnds) - nightBegins : 0
        return tick - (tick / day) * nightLength - tonight
    }

    /// The animals on screen at `clock` (a `dayClock`, or a frozen one).
    public static func animals(
        in snapshot: WorldSnapshot,
        xRange: ClosedRange<Int>,
        yRange: ClosedRange<Int>,
        clock: UInt64,
        ground: Ground
    ) -> [Animal] {
        // Inside for the winter, and too small to see far out.
        guard snapshot.date.season != .winter, snapshot.camera.zoom >= herdMinZoom else { return [] }
        let night = TimeOfDay(tick: snapshot.tickCount).phase == .night
        let near = { (anchor: TileCoordinate, pad: Int) in
            (xRange.lowerBound - pad ... xRange.upperBound + pad).contains(anchor.x)
                && (yRange.lowerBound - pad ... yRange.upperBound + pad).contains(anchor.y)
        }
        let homes = snapshot.buildings.values
            .filter { [.farm, .grainFarm, .house].contains($0.kind) && $0.state == .operational }
            .sorted { $0.id.raw < $1.id.raw }
        var herd: [Animal] = []
        for farm in homes where farm.kind != .house && near(farm.anchor, herdReach) {
            guard herd.count < maxHerd else { break }
            let pasture = pasture(around: farm, isFreeGrass: ground.isFreeGrass)
            guard !pasture.isEmpty else { continue }
            let kind: Kind = farm.kind == .farm ? .sheep : .cow
            var rng = DeterministicRNG(seed: UInt64(farm.id.raw) &* 0xA24B_AED4_963E_E407)
            let count = kind == .sheep ? 2 + Int(rng.next() % 3) : 1 + Int(rng.next() % 2)
            for slot in 0 ..< min(count, maxHerd - herd.count) {
                herd.append(grazer(farm.id, slot: slot, kind: kind, pasture: pasture, clock: clock))
            }
        }
        guard snapshot.camera.zoom >= henMinZoom, !night else { return herd }
        var hens: [Animal] = []
        for house in homes where house.kind == .house && near(house.anchor, 1) {
            guard hens.count < maxHens else { break }
            guard let pop = snapshot.housePopulations[house.id], pop.population > 0, pop.tier == .peasants else { continue }
            let yard = frontage(of: house, isYard: ground.isYard)
            guard !yard.isEmpty else { continue }
            var rng = DeterministicRNG(seed: UInt64(house.id.raw) &* 0x9FB2_1C65_1E98_DF25)
            let count = 1 + Int(rng.next() % 2)
            for slot in 0 ..< min(count, maxHens - hens.count) {
                hens.append(hen(house, slot: slot, yard: yard, clock: clock))
            }
        }
        return herd + hens
    }

    /// Free grass within `herdReach` of the farm's footprint, in reading order.
    static func pasture(around farm: Building, isFreeGrass: (TileCoordinate) -> Bool) -> [TileCoordinate] {
        let footprint = BuildingCatalog.spec(for: farm.kind).footprint
        return ((farm.anchor.y - herdReach) ..< (farm.anchor.y + footprint.height + herdReach)).flatMap { row in
            ((farm.anchor.x - herdReach) ..< (farm.anchor.x + footprint.width + herdReach)).map { TileCoordinate(x: $0, y: row) }
        }
        .filter(isFreeGrass)
    }

    /// The open yard tiles just past the house's +x and +y edges. Hens stand
    /// there and never on the house's own plot, whose log piles, barrels
    /// and garden beds are part of the house sprite.
    static func frontage(of house: Building, isYard: (TileCoordinate) -> Bool) -> [TileCoordinate] {
        let footprint = BuildingCatalog.spec(for: house.kind).footprint
        let right = (0 ..< footprint.height).map { TileCoordinate(x: house.anchor.x + footprint.width, y: house.anchor.y + $0) }
        let front = (0 ..< footprint.width).map { TileCoordinate(x: house.anchor.x + $0, y: house.anchor.y + footprint.height) }
        return (right + front).filter(isYard)
    }

    /// A round trip through the tiles reachable from `start` by steps to a
    /// 4-connected neighbour in `area`: each entry is next to the one before,
    /// and the last is next to the first, so every step walks over two
    /// neighbouring open tiles and nothing else.
    static func tour(from start: TileCoordinate, through area: Set<TileCoordinate>) -> [TileCoordinate] {
        var seen: Set<TileCoordinate> = [start]
        var route: [TileCoordinate] = [start]
        func visit(_ tile: TileCoordinate) {
            for (dx, dy) in [(1, 0), (0, 1), (-1, 0), (0, -1)] {
                let next = TileCoordinate(x: tile.x + dx, y: tile.y + dy)
                guard area.contains(next), seen.insert(next).inserted else { continue }
                route.append(next)
                visit(next)
                route.append(tile)
            }
        }
        visit(start)
        if route.count > 1 { route.removeLast() }
        return route
    }

    /// One leg of an animal's tour: from the tile it stood on last visit
    /// to this visit's, and how many ticks it has been on the way.
    struct Leg {
        let from: TileCoordinate
        let to: TileCoordinate
        let ticks: UInt64
    }

    private static func leg(tour: [TileCoordinate], base: UInt64, period: UInt64, clock: UInt64) -> Leg {
        let time = clock &+ base % period
        let visit = time / period
        let step = Int((base &+ visit) % UInt64(tour.count))
        let back = Int((base &+ visit &+ UInt64(tour.count) - 1) % UInt64(tour.count))
        return Leg(from: visit == 0 ? tour[step] : tour[back], to: tour[step], ticks: time % period)
    }

    static func grazer(_ farm: EntityID, slot: Int, kind: Kind, pasture: [TileCoordinate], clock: UInt64) -> Animal {
        let base = UInt64(farm.raw) &* 0x9E37_79B9_7F4A_7C15 ^ UInt64(slot) &* 0xBF58_476D_1CE4_E5B9
        let start = pasture[Int(base % UInt64(pasture.count))]
        let tour = tour(from: start, through: Set(pasture))
        let period = herdVisit.lowerBound + base % (herdVisit.upperBound - herdVisit.lowerBound + 1)
        let stop = leg(tour: tour, base: base, period: period, clock: clock)
        // A spot in the tile, 0.2 off its edges (tile (x, y) spans x ± 0.5).
        func spot(_ tile: TileCoordinate) -> (col: Double, row: Double) {
            var rng = spotRNG(base, tile)
            return (Double(tile.x) - 0.3 + Double(rng.next() % 600) / 1000, Double(tile.y) - 0.3 + Double(rng.next() % 600) / 1000)
        }
        let place = move(from: spot(stop.from), to: spot(stop.to), progress: Double(stop.ticks) / Double(herdWalkTicks))
        return Animal(home: farm, slot: slot, kind: kind, col: place.col, row: place.row, walking: place.walking, facing: place.facing)
    }

    static func hen(_ house: Building, slot: Int, yard: [TileCoordinate], clock: UInt64) -> Animal {
        let footprint = BuildingCatalog.spec(for: house.kind).footprint
        let base = UInt64(house.id.raw) &* 0xD6E8_FEB8_6659_FD93 ^ UInt64(slot) &* 0x2545_F491_4F6C_DD1D
        let start = yard[Int(base % UInt64(yard.count))]
        let tour = tour(from: start, through: Set(yard))
        let period = henVisit.lowerBound + base % (henVisit.upperBound - henVisit.lowerBound + 1)
        let stop = leg(tour: tour, base: base, period: period, clock: clock)
        // In the half of the yard tile next to the house.
        func spot(_ tile: TileCoordinate) -> (col: Double, row: Double) {
            var rng = spotRNG(base, tile)
            let along = -0.35 + Double(rng.next() % 700) / 1000
            let out = -0.4 + Double(rng.next() % 250) / 1000
            return tile.x == house.anchor.x + footprint.width
                ? (Double(tile.x) + out, Double(tile.y) + along)
                : (Double(tile.x) + along, Double(tile.y) + out)
        }
        let hop = move(from: spot(stop.from), to: spot(stop.to), progress: Double(stop.ticks) / Double(henHopTicks))
        return Animal(home: house.id, slot: slot, kind: .hen, col: hop.col, row: hop.row, walking: false, facing: hop.facing)
    }

    /// The generator for an animal's spot in one tile, so it comes back to
    /// the same spot whenever its tour returns there.
    private static func spotRNG(_ base: UInt64, _ tile: TileCoordinate) -> DeterministicRNG {
        DeterministicRNG(seed: base ^ UInt64(UInt32(bitPattern: Int32(tile.x))) << 20 ^ UInt64(UInt32(bitPattern: Int32(tile.y))))
    }

    private struct Place {
        let col: Double
        let row: Double
        let walking: Bool
        let facing: SpriteAtlas.WalkerFacing
    }

    private static func move(from: (col: Double, row: Double), to: (col: Double, row: Double), progress: Double) -> Place {
        let along = min(1, progress)
        return Place(
            col: from.col + (to.col - from.col) * along,
            row: from.row + (to.row - from.row) * along,
            walking: along < 1 && (from.col != to.col || from.row != to.row),
            facing: SpriteAtlas.WalkerFacing(stepX: to.col - from.col, stepY: to.row - from.row)
        )
    }
}
