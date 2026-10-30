/// Game content after loading, merging and validation, in load order:
/// packs in manifest order, then items in pack order.
public struct GameData: Equatable, Sendable {
    public var goods: [Good] = []
    public var buildings: [Building] = []
    public var cultures: [Culture] = []
    public var techs: [Tech] = []
    public var ages: [Age] = []
    public var tiers: [Tier] = []
    /// The distribution tunables; exactly one item declares them.
    public var logistics: [Logistics] = []
    /// Vehicles in load order.
    public var vehicles: [Vehicle] = []
    public var orders: [OrderTemplate] = []
    public var events: [SeasonalEvent] = []
    public var campaigns: [CampaignData] = []
    public var chapters: [ChapterData] = []

    /// Buildings that name `tech` in `unlockedBy`, in building order.
    public func unlocks(of tech: String) -> [String] {
        buildings.filter { $0.unlockedBy == tech }.map(\.id)
    }

    /// Appends every good that names a tier in `neededBy` to that tier's
    /// needs, in good order (design D2 of `tier-needs-data`).
    mutating func mergeNeededBy() {
        for index in tiers.indices {
            let tier = tiers[index].id
            tiers[index].needs += goods.filter { $0.neededBy.contains(tier) }.map(\.id)
        }
    }
}

/// An amount per good, kept in the order the pack wrote it.
public typealias GoodAmounts = [GoodAmount]

public struct GoodAmount: Equatable, Sendable {
    public var good: String
    public var amount: Int
}

/// A pack file and, when known, the line of the item or field.
public struct Origin: Equatable, Sendable, CustomStringConvertible {
    public var file: String
    public var line: Int?

    public var description: String {
        line.map { "\(file):\($0)" } ?? file
    }
}

public struct Good: Equatable, Sendable {
    public var id: String
    public var name: String
    public var unit: String
    public var basePrice: Int
    public var market: MarketLimits
    /// Tiers whose needs this good joins (design D2 of `tier-needs-data`).
    public var neededBy: [String]
    public var origin: Origin
}

/// Units per season the town market sells to (`buy`) and buys from
/// (`sell`) the player; 0 when the pack leaves one out.
public struct MarketLimits: Equatable, Sendable {
    public var buy: Int
    public var sell: Int

    public init(buy: Int = 0, sell: Int = 0) {
        self.buy = buy
        self.sell = sell
    }
}

public struct Recipe: Equatable, Sendable {
    public var inputs: GoodAmounts
    public var outputs: GoodAmounts
    public var cycleTicks: Int
}

public enum Placement: Equatable, Sendable {
    case shore(minLand: Int, minWater: Int)
    case terrain(type: String, minTiles: Int)
}

public struct Building: Equatable, Sendable {
    public var id: String
    public var name: String?
    public var legacyIds: [String]
    public var footprint: Size
    public var cost: Int
    public var upkeep: Int
    public var buildTicks: Int
    public var storage: Int?
    /// Units of each good a store holds, for stores that keep goods apart.
    public var storagePerGood: Int?
    /// The only goods a store takes; nil for every good.
    public var accepts: [String]?
    /// Ticks per planted forest tile, for buildings that plant.
    public var plantTicks: Int?
    /// Chebyshev radius around the footprint a gathering or planting building works.
    public var catchmentRadius: Int?
    public var category: String?
    public var materials: GoodAmounts
    public var recipe: Recipe?
    public var unlockedBy: String?
    public var obsoletedBy: String?
    public var culture: String?
    public var placement: Placement?
    public var hasCodeEffect: Bool
    /// A crop field, which blight slows.
    public var isCrop: Bool
    /// A good the building burns on an interval, from its store.
    public var fuel: Fuel?
    /// How it serves houses as a market hub; nil when it is none.
    public var hub: Hub?
    public var origin: Origin
}

/// A market hub's porter numbers (visible-distribution design D9).
public struct Hub: Equatable, Sendable {
    /// Road tiles from the hub to the houses it serves, at most.
    public var radius: Int
    /// Houses served per porter beyond the first.
    public var housesPerPorter: Int
    public var maxPorters: Int
    /// Units a porter carries at most.
    public var basketUnits: Int
    /// Consumptions of its houses a hub keeps of each good before it restocks.
    public var reserveConsumptions: Int

    public init(radius: Int, housesPerPorter: Int, maxPorters: Int, basketUnits: Int, reserveConsumptions: Int) {
        self.radius = radius
        self.housesPerPorter = housesPerPorter
        self.maxPorters = maxPorters
        self.basketUnits = basketUnits
        self.reserveConsumptions = reserveConsumptions
    }

    /// The fields in declaration order, for validation.
    var fields: [(String, Int)] {
        [
            ("radius", radius), ("housesPerPorter", housesPerPorter), ("maxPorters", maxPorters),
            ("basketUnits", basketUnits), ("reserveConsumptions", reserveConsumptions)
        ]
    }
}

public struct Size: Equatable, Sendable {
    public var width: Int
    public var height: Int
}

public struct LuxuryChain: Equatable, Sendable {
    public var raw: String
    public var good: String
    public var garden: String
    public var producer: String
}

public struct Culture: Equatable, Sendable {
    public var id: String
    public var name: String
    public var blurb: String
    /// Display names that override the tiers' own, keyed by tier id.
    public var tiers: [String: String]
    public var luxury: LuxuryChain
    public var signature: String
    public var residentNames: [String]
    public var origin: Origin

    /// The culture's name for `tier`, or the tier's own name.
    public func tierName(_ tier: Tier) -> String {
        tiers[tier.id] ?? tier.name
    }
}

public struct EraGate: Equatable, Sendable {
    public var tier: String
    public var residents: Int
}

public struct Tech: Equatable, Sendable {
    public var id: String
    public var name: String?
    public var cost: Int
    public var age: String
    public var prerequisites: [String]
    public var era: String?
    public var eraGate: EraGate?
    public var origin: Origin
}

public struct Age: Equatable, Sendable {
    public var id: String
    public var name: String?
    public var startYear: Int
    public var blurb: String
    public var signature: String
    public var rivalResidents: Int
    /// Seasons between crown orders in this age.
    public var orderEvery: Int
    public var origin: Origin
}

/// A timed request an issuer can make (`add-orders` D4).
public struct OrderTemplate: Equatable, Sendable {
    public var id: String
    /// `crown` or `rival`.
    public var issuer: String
    public var good: String
    public var title: String
    public var text: String
    public var minAge: String?
    public var seasons: Int
    public var size: Int
    public var min: Int
    public var max: Int
    public var reward: Int
    public var favour: Int
    public var penalty: Int
    public var origin: Origin
}

/// A seasonal event: its mechanic, when it can strike and its banners
/// (`add-event-counterplay` D3).
public struct SeasonalEvent: Equatable, Sendable {
    public var id: String
    /// `fire`, `blight`, `fever` or `festival`: the mechanic, in Swift.
    public var effect: String
    /// The possible onset seasons, in written order.
    public var seasons: [String]
    public var minAge: String?
    /// Draw weight per difficulty id.
    public var weights: [String: Int]
    /// Banners in written order.
    public var banners: [Banner]
    /// False keeps the event out of every draw and schedule until its
    /// mechanic ships (`add-event-counterplay` D14).
    public var enabled: Bool
    /// The first game year, from 1, a draw may pick it; 1 when unset.
    public var firstYear: Int = 1
    public var origin: Origin

    public struct Banner: Equatable, Sendable {
        public var key: String
        public var title: String
        public var text: String
    }
}

/// A house tier. Its position in load order is its raw value, from 1.
public struct Tier: Equatable, Sendable {
    public var id: String
    public var name: String
    public var capacity: Int
    public var taxPerResident: Int
    /// The tier's needs: as written while validating, then with every
    /// `neededBy` merged in.
    public var needs: [String]
    /// Consumption intervals a need may stay short before a house of this
    /// tier declines (design D3 of `decline-grace`); 1 when a pack says
    /// nothing.
    public var declineGrace: Int
    public var origin: Origin
}

/// How goods travel: when a haul takes a vehicle rather than going on
/// foot (visible-distribution design D9).
public struct Logistics: Equatable, Sendable {
    public var id: String
    /// Road tiles a haul must cover before it takes a vehicle.
    public var haulDistance: Int
    /// Units that must be ready for one destination before a vehicle goes.
    public var haulMinLoad: Int
    /// Ticks a producer's output waits for a vehicle load before it goes anyway.
    public var haulMaxWait: Int
    /// Consumptions of each need a house keeps in stock.
    public var houseStockConsumptions: Int
    /// Units of each need a house stock holds at least.
    public var houseStockMinimum: Int
    public var origin: Origin
}

/// A vehicle carriers use on long and bulk hauls from its age on, until a
/// later age's vehicle replaces it (#236).
public struct Vehicle: Equatable, Sendable {
    public var id: String
    /// The first age that uses it.
    public var age: String
    /// Units it carries at most.
    public var capacity: Int
    public var origin: Origin
}

/// An ordered list of chapters (`add-campaigns` D1).
public struct CampaignData: Equatable, Sendable {
    public var id: String
    public var title: String
    public var chapters: [String]
    /// The chapter whose win opens this campaign.
    public var opensAfter: String?
    public var origin: Origin
}

/// One goal of a chapter: a kind such as `residents` or `stock`, what it
/// names (an age, good, building or tech) and how many.
public struct ChapterGoal: Equatable, Sendable {
    public var kind: String
    public var subject: String?
    public var amount: Int?
    public var tier: String?
    public var hold: Bool
}

/// A chapter's terrain directive: `thinForest`, `pushMineOut`,
/// `noMountains` or `raiseMineSite`.
public struct ChapterDirective: Equatable, Sendable {
    public var kind: String
    /// `home`, or the rank of another island from 1.
    public var island: String?
    public var amount: Int?
}

/// A chapter's Normal money and stock.
public struct ChapterStart: Equatable, Sendable {
    public var money: Int
    public var stock: GoodAmounts
}

/// A difficulty's override of a chapter's money, stock or rival age years.
public struct ChapterStartData: Equatable, Sendable {
    public var money: Int?
    public var stock: GoodAmounts?
    public var rivalAgeYears: [String: Int]?
}

/// A seasonal event a chapter puts in a year.
public struct ChapterEvent: Equatable, Sendable {
    public var year: Int
    public var season: String
    public var event: String
}

/// A chapter's race: an age, or residents of a tier.
public struct ChapterRace: Equatable, Sendable {
    public var age: String?
    public var residents: Int?
    public var tier: String?
}

/// One chapter (`add-campaigns` D1, D9).
public struct ChapterData: Equatable, Sendable {
    public var id: String
    public var title: String
    public var intro: String
    public var ending: String
    public var layout: String
    public var seed: Int
    public var age: String
    public var culture: String?
    public var rivals: Int
    public var start: ChapterStart
    /// Per difficulty id.
    public var overrides: [String: ChapterStartData]
    public var directives: [ChapterDirective]
    public var closedBuildings: [String]
    public var closedTechs: [String]
    public var researched: [String]
    public var goals: [ChapterGoal]
    public var bonus: [ChapterGoal]
    public var deadline: Int?
    public var race: ChapterRace?
    public var collapse: Int?
    /// Earliest year per age id.
    public var rivalAgeYears: [String: Int]
    public var difficulties: [String]
    public var reward: ChapterReward
    public var firstSteps: Bool
    public var order: String?
    public var market: Bool
    public var kits: [String]
    public var comingLater: Bool
    public var events: [ChapterEvent]
    public var randomEvents: Bool
    public var origin: Origin
}

/// `banner`, `decor` or `mapPreset`, and its name.
public struct ChapterReward: Equatable, Sendable {
    public var kind: String
    public var name: String
}

/// `amount` of `good` burnt every `everyTicks` ticks.
public struct Fuel: Equatable, Sendable {
    public var good: String
    public var amount: Int
    public var everyTicks: Int
}
