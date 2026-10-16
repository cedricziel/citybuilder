#if canImport(ImageIO)
import Foundation

/// Scale and walker rules for the art-kit rollout.
///
/// - Migrated (`source = "isokit"`/`"svg"`) sprites ship an `@2x` twin at twice their size.
/// - SpriteKit loads only the `@2x` pages of an atlas on retina screens once the atlas has any, so in
///   such an atlas every `@1x` sprite needs a twin. Kit renders live in `Kit.atlas`, which keeps the
///   legacy atlases free of `@2x` art.
/// - An `@2x` file without its `@1x` sprite is an orphan.
/// - Migrated people (`walker-`, `carrier-`) are 24×30 points with eight gait frames per look and
///   facing (realistic-walkers).
enum KitRules {
    static let walkerSize = (width: 24, height: 30)
    static let walkerFacings = ["ne", "nw", "se", "sw"]
    static let walkerFrames = 8

    static func failures(images: [String: RGBAImage], catalog: GateCatalog) -> [SpriteContentGate.Failure] {
        let atlasHasTwins = images.keys.contains { SpriteFile($0).scale == 2 }
        var failures: [SpriteContentGate.Failure] = []
        var looks: Set<String> = []
        for (name, image) in images {
            let file = SpriteFile(name)
            if file.scale == 2, images[file.stem + ".png"] == nil {
                failures.append(.init(file: name, reason: .scaleTwinOrphan))
                continue
            }
            let migrated = catalog.entry(forSprite: name)?.isMigrated == true
            if file.scale == 1, migrated || atlasHasTwins, !hasTwin(name, image, in: images) {
                failures.append(.init(file: name, reason: .scaleTwinMismatch))
            }
            if migrated, file.stem.hasPrefix("walker-") || file.stem.hasPrefix("carrier-") {
                // `walker-woman-se-3` → the look `walker-woman`.
                looks.insert(file.stem.split(separator: "-").dropLast(2).joined(separator: "-"))
                if image.width != walkerSize.width * file.scale || image.height != walkerSize.height * file.scale {
                    failures.append(.init(file: name, reason: .walkerSize))
                }
            }
        }
        for look in looks.sorted() {
            for facing in walkerFacings {
                for frame in 0 ..< walkerFrames where images["\(look)-\(facing)-\(frame).png"] == nil {
                    failures.append(.init(file: "\(look)-\(facing)-\(frame).png", reason: .walkerFramesMissing))
                }
            }
        }
        return failures
    }

    /// The `@2x` twin exists at exactly twice the size.
    private static func hasTwin(_ name: String, _ image: RGBAImage, in images: [String: RGBAImage]) -> Bool {
        guard let twin = images[SpriteFile(name).stem + "@2x.png"] else { return false }
        return twin.width == image.width * 2 && twin.height == image.height * 2
    }
}
#endif
