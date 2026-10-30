import GameDataModel

/// A small, valid world split into packs the way the real game data is.
enum Fixtures {
    static let core = """
    defaults:
      producer: &producer
        footprint: [2, 2]
        cost: 120
        upkeep: 1
        buildTicks: 30
    items:
      - { kind: Good, id: wood, name: Wood, unit: logs, basePrice: 4 }
      - { kind: Good, id: planks, name: Planks, unit: bundles, basePrice: 8 }
      - { kind: Tier, id: peasants, name: Peasants, capacity: 4, taxPerResident: 1, needs: [planks] }
      - { kind: Tier, id: citizens, name: Citizens, capacity: 6, taxPerResident: 2, needs: [planks] }
      - { kind: Tier, id: merchants, name: Merchants, capacity: 8, taxPerResident: 4, needs: [planks, wood] }
      - kind: Logistics
        id: logistics
        haulDistance: 12
        haulMinLoad: 3
        haulMaxWait: 200
        houseStockConsumptions: 2
        houseStockMinimum: 2
      - { kind: Vehicle, id: barrow, age: antiquity, capacity: 3 }
      - kind: Building
        id: house
        effect: code
        footprint: [2, 2]
        cost: 50
        storage: 8
        category: town
        materials: { planks: 4 }
      - kind: Building
        id: lumberjack-hut
        name: Lumberjack
        legacyIds: [lumberjack_hut]
        footprint: [2, 2]
        cost: 80
        storage: 16
        catchmentRadius: 2
        category: gather
        recipe: { outputs: { wood: 1 }, cycleTicks: 30 }
      - kind: Building
        id: sawmill
        <<: *producer
        upkeep: 2
        materials: { wood: 4, planks: 1 }
        recipe: { inputs: { wood: 1 }, outputs: { planks: 1 }, cycleTicks: 25 }
      - kind: Building
        id: port
        effect: code
        footprint: [2, 3]
        cost: 250
        placement: { shore: { minLand: 1, minWater: 1 } }
        unlockedBy: seafaring
      - { kind: Tech, id: scholarship, cost: 30, age: antiquity }
      - { kind: Tech, id: seafaring, cost: 60, age: medieval }
      - { kind: Tech, id: cultivation, cost: 50, age: medieval }
    """

    static let ages = """
    items:
      - kind: Age
        id: antiquity
        startYear: -499
        blurb: Stone towns.
        signature: monument
        rivalResidents: 0
      - { kind: Age, id: medieval, startYear: 1200, blurb: Timber and tile., signature: monument, rivalResidents: 24 }
      - kind: Tech
        id: feudal-order
        name: Feudal Order
        cost: 150
        age: antiquity
        era: medieval
        eraGate: { tier: citizens, residents: 20 }
      - kind: Building
        id: monument
        effect: code
        footprint: [3, 3]
        cost: 300
        recipe: { inputs: { wood: 2 }, cycleTicks: 60 }
    """

    static let culture = """
    defaults:
      garden: &garden
        footprint: [2, 2]
        cost: 60
        unlockedBy: cultivation
    items:
      - kind: Culture
        id: northern-european
        name: Northern European
        blurb: Half-timbered towns.
        tiers: { peasants: Peasants, citizens: Citizens, merchants: Merchants }
        luxury: { raw: hops, good: beer, garden: hop-garden, producer: brewery }
        signature: mead-hall
        residentNames: [Astrid, Bjorn]
      - { kind: Good, id: hops, name: Hops, unit: bales, basePrice: 3 }
      - { kind: Good, id: beer, name: Beer, unit: casks, basePrice: 16 }
      - kind: Building
        id: hop-garden
        <<: *garden
        culture: northern-european
        recipe: { outputs: { hops: 1 }, cycleTicks: 40 }
      - kind: Building
        id: brewery
        culture: northern-european
        unlockedBy: cultivation
        footprint: [2, 2]
        cost: 120
        recipe: { inputs: { hops: 2 }, outputs: { beer: 1 }, cycleTicks: 50 }
      - kind: Building
        id: mead-hall
        culture: northern-european
        effect: code
        footprint: [3, 3]
        cost: 180
    """

    /// The default packs, in manifest order.
    static let packs = [("core", core), ("cultures/northern-european", culture), ("ages", ages)]

    /// Packs keyed by manifest name, in manifest order.
    static func source(_ packs: [(String, String)] = packs, extraFiles: [String: String] = [:]) -> InMemorySource {
        var files = extraFiles
        files["index.yaml"] = "schemaVersion: 1\npacks:\n" + packs.map { "  - \($0.0)\n" }.joined()
        for (name, body) in packs {
            files["packs/\(name).yaml"] = body
        }
        return InMemorySource(files: files)
    }

    /// The default packs with `core` replaced, and no culture pack.
    static func withCore(_ core: String) -> InMemorySource {
        source([("core", core), ("ages", ages)])
    }

    /// The default packs with the culture pack replaced.
    static func withCulture(_ culture: String) -> InMemorySource {
        source([("core", core), ("cultures/n", culture), ("ages", ages)])
    }

    /// The default packs followed by `packs/extra.yaml`.
    static func withExtraPack(_ extra: String) -> InMemorySource {
        source(packs + [("extra", extra)])
    }

    static func load(_ source: InMemorySource = source()) -> Result<GameData, GameDataErrors> {
        GameDataLoader.load(from: source)
    }

    static func errors(_ source: InMemorySource) -> [String] {
        switch load(source) {
        case .success: []
        case let .failure(failure): failure.diagnostics.map(\.description)
        }
    }

    /// A pack whose items are written as flow mappings of raw YAML values.
    static func pack(_ items: [[String: String]]) -> String {
        "items:\n" + items.map { item in
            "  - { " + item.sorted { $0.key < $1.key }.map { "\($0.key): \($0.value)" }.joined(separator: ", ") + " }\n"
        }.joined()
    }

    /// Exactly the required fields of each kind, as raw YAML values.
    static let minimalItems: [String: [String: String]] = [
        "Good": ["id": "salt", "name": "Salt", "unit": "sacks", "basePrice": "3"],
        "Building": ["id": "salt-pan", "footprint": "[1, 1]", "cost": "10"],
        "Culture": [
            "id": "nordic", "name": "Nordic", "blurb": "Cold.",
            "luxury": "{ raw: hops, good: beer, garden: hop-garden, producer: brewery }",
            "signature": "mead-hall", "residentNames": "[Ada]"
        ],
        "Tech": ["id": "salting", "cost": "10", "age": "antiquity"],
        "Age": ["id": "bronze", "startYear": "-900", "blurb": "Bronze.", "signature": "monument", "rivalResidents": "0"],
        "Tier": ["id": "nobles", "name": "Nobles", "capacity": "10", "taxPerResident": "8", "needs": "[wood]"],
        "Logistics": [
            "id": "carts", "haulDistance": "8", "haulMinLoad": "2", "haulMaxWait": "50",
            "houseStockConsumptions": "2", "houseStockMinimum": "2"
        ],
        "Vehicle": ["id": "barrow", "age": "antiquity", "capacity": "3"],
        "Order": [
            "id": "crown-wood", "issuer": "crown", "good": "wood", "title": "Wood", "text": "Wood for the winter.",
            "seasons": "2", "size": "80", "min": "10", "max": "50", "reward": "120"
        ],
        "Event": [
            "id": "fire", "effect": "fire", "seasons": "[summer]", "weight": "{ easy: 1, normal: 1, hard: 2 }",
            "banners": "{ warning: { title: Dry, text: Fire risk. } }"
        ],
        "Campaign": ["id": "chronicle", "title": "Chronicle", "chapters": "[first-fires]"],
        "Chapter": [
            "id": "first-fires", "title": "First Fires", "intro": "Smoke rises.", "ending": "A village.",
            "layout": "single-island", "seed": "101", "age": "antiquity", "money": "1000",
            "goals": "[{ residents: 24 }]", "reward": "{ banner: Hearth }"
        ]
    ]

    /// Every optional field of each kind, as raw YAML values.
    static let optionalFields: [String: [String: String]] = [
        "Good": ["market": "{ buy: 10, sell: 20 }", "neededBy": "[merchants]"],
        "Building": [
            "name": "Salt Pan", "legacyIds": "[salt_pan]", "upkeep": "1", "buildTicks": "20", "storage": "16", "storagePerGood": "8",
            "plantTicks": "40",
            "catchmentRadius": "2",
            "category": "gather", "materials": "{ wood: 1 }", "recipe": "{ outputs: { wood: 1 }, cycleTicks: 10 }",
            "unlockedBy": "seafaring", "obsoletedBy": "cultivation", "culture": "northern-european",
            "placement": "{ terrain: { type: beach, minTiles: 1 } }", "effect": "code",
            "crop": "true", "accepts": "[wood]", "fuel": "{ good: wood, amount: 1, everyTicks: 50 }",
            "hub": "{ radius: 4, housesPerPorter: 2, maxPorters: 3, basketUnits: 5, reserveConsumptions: 1 }"
        ],
        "Culture": ["tiers": "{ peasants: P, citizens: C, merchants: M }"],
        "Tech": [
            "name": "Salting", "prerequisites": "[scholarship]", "era": "medieval",
            "eraGate": "{ tier: citizens, residents: 1 }"
        ],
        "Age": ["name": "Bronze", "orderEvery": "3"],
        "Tier": ["declineGrace": "3"],
        "Order": ["minAge": "medieval", "favour": "3", "penalty": "1"],
        "Event": ["minAge": "medieval", "enabled": "false", "firstYear": "4"],
        "Campaign": ["opensAfter": "the-guild-charter"],
        "Chapter": [
            "culture": "northern-european", "rivals": "0", "stock": "{ wood: 6 }", "overrides": "{ easy: { money: 2000 } }",
            "directives": "[{ noMountains: home }]", "closedBuildings": "[port]", "closedTechs": "[seafaring]",
            "researched": "[cultivation]", "bonus": "[{ stock: wood, count: 5 }]", "lose": "{ deadline: -496 }",
            "rivalAgeYears": "{ medieval: 1207 }", "difficulties": "[easy, normal]",
            "sweep": "{ firstSteps: true, order: careful, market: false, kits: [signature] }", "comingLater": "false",
            "events": "[]", "randomEvents": "false"
        ]
    ]
}
