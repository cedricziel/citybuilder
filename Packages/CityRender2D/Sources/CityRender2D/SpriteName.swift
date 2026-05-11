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
    }

    public static func validate(_ name: String) -> Result<Void, ValidationError> {
        if name.contains(where: \.isUppercase) {
            return .failure(.spriteNameNotLowercase)
        }
        if name.contains("_") {
            return .failure(.spriteNameUsesUnderscore)
        }
        if SpriteAtlasRouting.atlasName(for: name) == nil {
            return .failure(.spriteNameUnknownPrefix)
        }
        return .success(())
    }
}
