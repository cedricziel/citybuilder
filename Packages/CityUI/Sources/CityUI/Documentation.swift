import Foundation

/// MVP release-prep documentation. Kept in CityUI so it ships with the
/// app and is searchable in source — not committed as a Markdown file
/// because spec scenarios are the canonical documentation.
public enum MVPRelease {
    public static let scope: [String] = [
        "Universal binary: iPhone, iPad, Mac",
        "Fixed 96×96 procedural island",
        "Tile placement: roads, warehouses, lumberjack, sawmill, house, town center",
        "Wood → Planks → Houses production chain",
        "Carrier data model (full walking polish in next milestone)",
        "Population growth/decline driven by food + planks satisfaction",
        "Single-currency money balance with tax + upkeep + bankruptcy",
        "Save/load to disk; CloudKit sync data model in place",
        "2.5D iso renderer with snapshot reconciliation + 3D portraits"
    ]

    public static let releaseNotes: String = """
    Citybuilder v0.1.0 (MVP)

    First playable build. One fixed island, basic production chain, save +
    load, sync data model. Universal across iPhone, iPad, and Mac.

    Known limitations:
    - Carriers do not yet physically walk roads each tick (M5 polish).
    - 60 fps validation on iPad pending hardware verification.
    - CloudKit production schema not yet pushed (developer-account step).
    """
}
