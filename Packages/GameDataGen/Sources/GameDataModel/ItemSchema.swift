/// The fields each item kind accepts. The published JSON Schema must list
/// the same sets; a test compares them.
public enum ItemSchema {
    public struct Fields: Equatable, Sendable {
        public var required: Set<String>
        public var optional: Set<String>

        public var allowed: Set<String> {
            required.union(optional).union(["kind"])
        }
    }

    public static let kinds: [String: Fields] = [
        "Good": Fields(required: ["id", "name", "unit", "basePrice"], optional: ["market", "neededBy"]),
        "Building": Fields(
            required: ["id", "footprint", "cost"],
            optional: [
                "name", "legacyIds", "upkeep", "buildTicks", "storage", "storagePerGood", "plantTicks", "catchmentRadius", "category",
                "materials",
                "recipe",
                "unlockedBy", "obsoletedBy", "culture", "placement", "effect", "crop"
            ]
        ),
        "Culture": Fields(
            required: ["id", "name", "blurb", "luxury", "signature", "residentNames"],
            optional: ["tiers"]
        ),
        "Tech": Fields(required: ["id", "cost", "age"], optional: ["name", "prerequisites", "era", "eraGate"]),
        "Age": Fields(required: ["id", "startYear", "blurb", "signature", "rivalResidents"], optional: ["name", "orderEvery"]),
        "Order": Fields(
            required: ["id", "issuer", "good", "title", "text", "seasons", "size", "min", "max", "reward"],
            optional: ["minAge", "favour", "penalty"]
        ),
        "Tier": Fields(required: ["id", "name", "capacity", "taxPerResident", "needs"], optional: []),
        "Event": Fields(required: ["id", "effect", "seasons", "weight", "banners"], optional: ["minAge"])
    ]

    /// The mechanics a seasonal event can have, each written in Swift.
    public static let eventEffects: Set<String> = ["fire", "blight", "fever", "festival"]
    /// The effects that harm the town and so need a season of warning.
    public static let hazardEffects = eventEffects.subtracting(["festival"])
    /// Seasons in calendar order.
    public static let seasons = ["spring", "summer", "autumn", "winter"]
    /// Difficulties in the order the `weight` mapping lists them.
    public static let difficulties = ["easy", "normal", "hard"]
    /// The banners an event can show, in the order they are emitted.
    public static let eventBanners = ["warning", "onset", "ignition", "end", "endNoLoss", "endNoFire", "request", "held", "missed"]
    public static let orderIssuers: Set<String> = ["crown", "rival"]
    public static let buildingCategories: Set<String> = ["town", "gather", "craft"]
    public static let terrainTypes: Set<String> = ["grass", "forest", "beach", "water", "mountain"]
    /// Buildings whose hand-written behaviour harvests within their catchment, so they must declare
    /// `catchmentRadius`.
    public static let catchmentHarvesters: Set<String> = ["lumberjack-hut"]
}
