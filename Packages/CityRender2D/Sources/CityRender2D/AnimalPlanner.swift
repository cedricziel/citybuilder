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

    /// One animal: its home and its place in the herd or flock.
    public struct Key: Hashable, Sendable {
        public let home: EntityID
        public let slot: Int
    }

    /// The animals on screen at `clock` (a `dayClock`, or a frozen one).
    /// `tours` keeps each animal's round from call to call, so a tile built
    /// on near its home never makes it jump.
    public static func animals(
        in snapshot: WorldSnapshot,
        visible: (x: ClosedRange<Int>, y: ClosedRange<Int>),
        clock: UInt64,
        ground: Ground,
        tours: inout [Key: Tour]
    ) -> [Animal] {
        var kept: [Key: Tour] = [:]
        defer { tours = kept }
        // Inside for the winter, and too small to see far out.
        guard snapshot.date.season != .winter, snapshot.camera.zoom >= herdMinZoom else { return [] }
        func roam(_ key: Key, area: [TileCoordinate], pace: Pace) -> Place {
            let tour = tour(for: tours[key], area: area, pace: pace, clock: clock)
            kept[key] = tour
            return place(on: tour, pace: pace, clock: clock)
        }
        let (xRange, yRange) = visible
        let night = TimeOfDay(tick: snapshot.tickCount).phase == .night
        let near = { (anchor: TileCoordinate, pad: Int) in
            (xRange.lowerBound - pad ... xRange.upperBound + pad).contains(anchor.x)
                && (yRange.lowerBound - pad ... yRange.upperBound + pad).contains(anchor.y)
        }
        // The budget goes to the homes nearest the camera centre, so panning
        // to a farm gives it animals and those on screen keep theirs.
        let camera = snapshot.camera
        let distance = { (home: Building) -> Double in
            let dx = Double(home.anchor.x) - camera.centerX, dy = Double(home.anchor.y) - camera.centerY
            return dx * dx + dy * dy
        }
        let homes = snapshot.buildings.values
            .filter { [.farm, .grainFarm, .house].contains($0.kind) && $0.state == .operational }
            .map { (home: $0, distance: distance($0)) }
            .sorted { ($0.distance, $0.home.id.raw) < ($1.distance, $1.home.id.raw) }
            .map(\.home)
        var herd: [Animal] = []
        for farm in homes where farm.kind != .house && near(farm.anchor, herdReach) {
            guard herd.count < maxHerd else { break }
            let pasture = pasture(around: farm, isFreeGrass: ground.isFreeGrass)
            guard !pasture.isEmpty else { continue }
            let kind: Kind = farm.kind == .farm ? .sheep : .cow
            var rng = DeterministicRNG(seed: UInt64(farm.id.raw) &* 0xA24B_AED4_963E_E407)
            let count = kind == .sheep ? 2 + Int(rng.next() % 3) : 1 + Int(rng.next() % 2)
            for slot in 0 ..< min(count, maxHerd - herd.count) {
                herd.append(grazer(farm.id, slot: slot, kind: kind, pasture: pasture, roam: roam))
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
                hens.append(hen(house, slot: slot, yard: yard, roam: roam))
            }
        }
        return herd + hens
    }

    /// Free grass within `herdReach` of the farm's footprint, in reading order.
    static func pasture(around farm: Building, isFreeGrass: (TileCoordinate) -> Bool) -> [TileCoordinate] {
        let footprint = farm.footprint
        return ((farm.anchor.y - herdReach) ..< (farm.anchor.y + footprint.height + herdReach)).flatMap { row in
            ((farm.anchor.x - herdReach) ..< (farm.anchor.x + footprint.width + herdReach)).map { TileCoordinate(x: $0, y: row) }
        }
        .filter(isFreeGrass)
    }

    /// The open yard tiles just past the house's +x and +y edges. Hens stand
    /// there and never on the house's own plot, whose log piles, barrels
    /// and garden beds are part of the house sprite.
    static func frontage(of house: Building, isYard: (TileCoordinate) -> Bool) -> [TileCoordinate] {
        let footprint = house.footprint
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

    /// A spot in fractional tile coordinates.
    public struct Spot: Equatable, Sendable {
        let col: Double
        let row: Double
    }

    /// How an animal moves along its round: its hash, the ticks between
    /// visits and the ticks a step takes, and its spot in each tile.
    struct Pace {
        let base: UInt64
        let period: UInt64
        let walkTicks: UInt64
        let spot: (TileCoordinate) -> Spot
    }

    /// An animal's round, kept by the scene from pass to pass.
    public struct Tour: Equatable, Sendable {
        /// The round's tiles in walking order (`tour(from:through:)`).
        let tiles: [TileCoordinate]
        /// Added to the clock to give the time into the round.
        let shift: UInt64
        /// The step of the round the animal makes in visit 0.
        let first: UInt64
        /// Where visit 0 sets out from, for a round planned on the way.
        let entry: Spot?
        /// The clock the round was planned at.
        let since: UInt64
    }

    /// The round to follow at `clock`: the kept one while all its tiles are
    /// open, else a new one from where the animal stands to the tile it was
    /// heading for, or the open tile nearest it.
    static func tour(for previous: Tour?, area: [TileCoordinate], pace: Pace, clock: UInt64) -> Tour {
        let open = Set(area)
        guard let previous, clock >= previous.since else {
            let start = area[Int(pace.base % UInt64(area.count))]
            return Tour(tiles: tour(from: start, through: open), shift: pace.base % pace.period, first: pace.base, entry: nil, since: 0)
        }
        guard !previous.tiles.allSatisfy(open.contains) else { return previous }
        let here = place(on: previous, pace: pace, clock: clock)
        let goal = previous.tiles[step(on: previous, period: pace.period, clock: clock)]
        let start = open.contains(goal) ? goal : area.min { distance($0, goal) < distance($1, goal) } ?? goal
        return Tour(
            tiles: tour(from: start, through: open), shift: 0 &- clock, first: 0, entry: Spot(col: here.col, row: here.row),
            since: clock
        )
    }

    private static func distance(_ lhs: TileCoordinate, _ rhs: TileCoordinate) -> Int {
        abs(lhs.x - rhs.x) + abs(lhs.y - rhs.y)
    }

    private static func step(on tour: Tour, period: UInt64, clock: UInt64) -> Int {
        Int((tour.first &+ (clock &+ tour.shift) / period) % UInt64(tour.tiles.count))
    }

    /// Where the animal is at `clock`: on its way from the tile it stood on
    /// last visit (or the round's entry spot) to this visit's.
    static func place(on tour: Tour, pace: Pace, clock: UInt64) -> Place {
        let (time, period) = (clock &+ tour.shift, pace.period)
        let count = UInt64(tour.tiles.count)
        let to = tour.tiles[step(on: tour, period: period, clock: clock)]
        let back = tour.tiles[Int((tour.first &+ time / period &+ count - 1) % count)]
        let from = time / period == 0 ? tour.entry ?? pace.spot(to) : pace.spot(back)
        return move(from: from, to: pace.spot(to), progress: Double(time % period) / Double(pace.walkTicks))
    }

    typealias Roam = (Key, [TileCoordinate], Pace) -> Place

    static func grazer(_ farm: EntityID, slot: Int, kind: Kind, pasture: [TileCoordinate], roam: Roam) -> Animal {
        let base = UInt64(farm.raw) &* 0x9E37_79B9_7F4A_7C15 ^ UInt64(slot) &* 0xBF58_476D_1CE4_E5B9
        let period = herdVisit.lowerBound + base % (herdVisit.upperBound - herdVisit.lowerBound + 1)
        // A spot in the tile, 0.2 off its edges (tile (x, y) spans x ± 0.5).
        func spot(_ tile: TileCoordinate) -> Spot {
            var rng = spotRNG(base, tile)
            return Spot(
                col: Double(tile.x) - 0.3 + Double(rng.next() % 600) / 1000,
                row: Double(tile.y) - 0.3 + Double(rng.next() % 600) / 1000
            )
        }
        let place = roam(Key(home: farm, slot: slot), pasture, Pace(base: base, period: period, walkTicks: herdWalkTicks, spot: spot))
        return Animal(home: farm, slot: slot, kind: kind, col: place.col, row: place.row, walking: place.walking, facing: place.facing)
    }

    static func hen(_ house: Building, slot: Int, yard: [TileCoordinate], roam: Roam) -> Animal {
        let footprint = house.footprint
        let base = UInt64(house.id.raw) &* 0xD6E8_FEB8_6659_FD93 ^ UInt64(slot) &* 0x2545_F491_4F6C_DD1D
        let period = henVisit.lowerBound + base % (henVisit.upperBound - henVisit.lowerBound + 1)
        // In the half of the yard tile next to the house.
        func spot(_ tile: TileCoordinate) -> Spot {
            var rng = spotRNG(base, tile)
            let along = -0.35 + Double(rng.next() % 700) / 1000
            let out = -0.4 + Double(rng.next() % 250) / 1000
            return tile.x == house.anchor.x + footprint.width
                ? Spot(col: Double(tile.x) + out, row: Double(tile.y) + along)
                : Spot(col: Double(tile.x) + along, row: Double(tile.y) + out)
        }
        let hop = roam(Key(home: house.id, slot: slot), yard, Pace(base: base, period: period, walkTicks: henHopTicks, spot: spot))
        return Animal(home: house.id, slot: slot, kind: .hen, col: hop.col, row: hop.row, walking: false, facing: hop.facing)
    }

    /// The generator for an animal's spot in one tile, so it comes back to
    /// the same spot whenever its tour returns there.
    private static func spotRNG(_ base: UInt64, _ tile: TileCoordinate) -> DeterministicRNG {
        DeterministicRNG(seed: base ^ UInt64(UInt32(bitPattern: Int32(tile.x))) << 20 ^ UInt64(UInt32(bitPattern: Int32(tile.y))))
    }

    struct Place {
        let col: Double
        let row: Double
        let walking: Bool
        let facing: SpriteAtlas.WalkerFacing
    }

    private static func move(from: Spot, to: Spot, progress: Double) -> Place {
        let along = min(1, progress)
        return Place(
            col: from.col + (to.col - from.col) * along,
            row: from.row + (to.row - from.row) * along,
            walking: along < 1 && (from.col != to.col || from.row != to.row),
            facing: SpriteAtlas.WalkerFacing(stepX: to.col - from.col, stepY: to.row - from.row)
        )
    }
}
