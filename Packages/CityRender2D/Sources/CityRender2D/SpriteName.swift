import Foundation

/// Validator for the sprite-asset-pipeline naming grammar.
///
/// A conforming sprite name MUST be lowercase, hyphen-separated, with
/// no spaces, underscores, or non-ASCII characters, and start with one
/// of the routing prefixes the `SpriteAtlasRouting` table knows about.
/// The catalog runs every declared name through `validate` at startup
/// so a non-conforming addition fails fast at compile-adjacent time.
public enum SpriteName {
    public enum ValidationError: String, Error, Sendable {
        case spriteNameNotLowercase = "sprite_name_not_lowercase"
        case spriteNameUsesUnderscore = "sprite_name_uses_underscore"
        case spriteNameUnknownPrefix = "sprite_name_unknown_prefix"
        /// Shore-building sprite is missing the orientation slot
        /// required after `add-archipelago-and-sea`.
        case shoreBuildingMissingOrientation = "shore_building_missing_orientation"
        /// Ship facing must be one of `n`, `ne`, `e`, `se`, `s`, `sw`,
        /// `w`, `nw` — the 8 compass directions.
        case shipFacingUnknown = "ship_facing_unknown"
    }

    /// Building kinds that opt into the shore-placement grammar. Kept
    /// as a string set in CityRender2D to avoid a CityCore round-trip
    /// for what is purely a sprite-naming concern.
    public static let shorePlacementKindRawValues: Set<String> = ["port", "shipyard"]

    /// 8-compass facing set used by ship sprites.
    public static let shipFacings: [String] = ["n", "ne", "e", "se", "s", "sw", "w", "nw"]

    /// 4-cardinal orientation set used by shore-placement buildings.
    public static let shoreOrientations: [String] = ["n", "s", "e", "w"]

    public static func validate(_ name: String) -> Result<Void, ValidationError> {
        if name.contains(where: \.isUppercase) {
            return .failure(.spriteNameNotLowercase)
        }
        if name.contains("_") {
            return .failure(.spriteNameUsesUnderscore)
        }
        guard SpriteAtlasRouting.atlasName(for: name) != nil else {
            return .failure(.spriteNameUnknownPrefix)
        }
        if name.hasPrefix("ship-") {
            return validateShip(name)
        }
        if name.hasPrefix("building-") {
            return validateBuilding(name)
        }
        return .success(())
    }

    private static func validateShip(_ name: String) -> Result<Void, ValidationError> {
        // ship-<facing>-<frame>: 3 segments.
        let segments = name.split(separator: "-")
        guard segments.count == 3 else { return .failure(.shipFacingUnknown) }
        let facing = String(segments[1])
        guard shipFacings.contains(facing) else {
            return .failure(.shipFacingUnknown)
        }
        return .success(())
    }

    private static func validateBuilding(_ name: String) -> Result<Void, ValidationError> {
        // building-<kind>[-<orientation>][-<state>][-<frame>] —
        // orientation slot required for shore-placement kinds.
        let segments = name.split(separator: "-")
        guard segments.count >= 2 else { return .success(()) }
        let kindRaw = String(segments[1])
        guard shorePlacementKindRawValues.contains(kindRaw) else {
            // Non-shore building: existing grammar, no orientation check.
            return .success(())
        }
        // Shore building: the third segment must be a valid orientation.
        guard segments.count >= 3,
              shoreOrientations.contains(String(segments[2]))
        else {
            return .failure(.shoreBuildingMissingOrientation)
        }
        return .success(())
    }
}
