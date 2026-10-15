#if canImport(ImageIO)
import Foundation

/// Rules that apply only to sprites whose catalog entry has migrated to the art kit
/// (`source = "isokit"` or `"svg"`): every sprite ships an exact `@2x` twin, and walkers are
/// 10×16 points with four gait frames per facing. Legacy sprites keep their old shape until
/// their family migrates.
enum KitRules {
    static let walkerSize = (width: 10, height: 16)
    static let walkerFacings = ["ne", "nw", "se", "sw"]
    static let walkerFrames = 4

    static func failures(images: [String: RGBAImage], catalog: GateCatalog) -> [SpriteContentGate.Failure] {
        var failures: [SpriteContentGate.Failure] = []
        var migratedWalkers = false
        for (name, image) in images {
            let file = SpriteFile(name)
            guard let entry = catalog.entry(forSprite: name), entry.isMigrated else { continue }
            if file.scale == 1, !hasTwin(name, image, in: images) {
                failures.append(.init(file: name, reason: .scaleTwinMismatch))
            }
            if file.stem.hasPrefix("walker-") {
                migratedWalkers = true
                if image.width != walkerSize.width * file.scale || image.height != walkerSize.height * file.scale {
                    failures.append(.init(file: name, reason: .walkerSize))
                }
            }
        }
        if migratedWalkers {
            for facing in walkerFacings {
                for frame in 0 ..< walkerFrames where images["walker-\(facing)-\(frame).png"] == nil {
                    failures.append(.init(file: "walker-\(facing)-\(frame).png", reason: .walkerFramesMissing))
                }
            }
        }
        return failures
    }

    private static func hasTwin(_ name: String, _ image: RGBAImage, in images: [String: RGBAImage]) -> Bool {
        guard let twin = images[SpriteFile(name).stem + "@2x.png"] else { return false }
        return twin.width == image.width * 2 && twin.height == image.height * 2
    }
}
#endif
