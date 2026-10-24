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
                "name", "legacyIds", "upkeep", "buildTicks", "storage", "plantTicks", "category", "materials", "recipe",
                "unlockedBy", "obsoletedBy", "culture", "placement", "effect"
            ]
        ),
        "Culture": Fields(
            required: ["id", "name", "blurb", "luxury", "signature", "residentNames"],
            optional: ["tiers"]
        ),
        "Tech": Fields(required: ["id", "cost", "age"], optional: ["name", "prerequisites", "era", "eraGate"]),
        "Age": Fields(required: ["id", "startYear", "blurb", "signature", "rivalResidents"], optional: ["name"]),
        "Tier": Fields(required: ["id", "name", "capacity", "taxPerResident", "needs"], optional: []),
        "Logistics": Fields(required: ["id", "cartDistance", "cartMinLoad", "cartCapacity", "cartMaxWait"], optional: [])
    ]

    public static let buildingCategories: Set<String> = ["town", "gather", "craft"]
    public static let terrainTypes: Set<String> = ["grass", "forest", "beach", "water", "mountain"]
}
