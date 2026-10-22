#if canImport(ImageIO)
import Foundation
import ImageIO

/// Content checks for committed sprite PNGs. The byte-identical regen
/// check proves the atlas reproduces from `_sheets/`; this proves the
/// atlas shows something sane. Spec: `sprite-asset-pipeline`.
public enum SpriteContentGate {
    /// Allowed drift, in pixels, of an operational frame's left, right
    /// and bottom edges from its base sprite's.
    public static let silhouetteTolerance = 2

    public enum Reason: String, Sendable {
        case terrainCoverageBelowThreshold = "terrain_coverage_below_threshold"
        case terrainOutsideDiamond = "terrain_outside_diamond"
        case frameEmpty = "frame_empty"
        case frameIncoherent = "frame_incoherent"
        case frameMisaligned = "frame_misaligned"
        case notGrounded = "not_grounded"
        /// A sprite's `@2x` twin is missing, not exactly twice its size, or (for legacy art) not its
        /// exact nearest-neighbour double.
        case scaleTwinMismatch = "scale_twin_mismatch"
        /// An `@2x` file has no `@1x` sprite.
        case scaleTwinOrphan = "scale_twin_orphan"
        /// A migrated walker frame is not 10×16 points.
        case walkerSize = "walker_size"
        /// A migrated walker facing lacks one of its four gait frames.
        case walkerFramesMissing = "walker_frames_missing"
    }

    public struct Failure: Equatable, Sendable {
        public let file: String
        public let reason: Reason

        public init(file: String, reason: Reason) {
            self.file = file
            self.reason = reason
        }
    }

    public struct Report: Sendable {
        public let exitCode: Int32
        public let output: String
    }

    /// Inspects every `*.atlas/*.png` under `resourcesRoot`. Failures
    /// are sorted by file name, then reason, so output is stable.
    public static func inspect(resourcesRoot: URL, coherenceMaxDistance: Double) throws -> [Failure] {
        let catalog = try GateCatalog.load(resourcesRoot: resourcesRoot)
        var failures: [Failure] = []
        for atlas in try atlasDirectories(in: resourcesRoot) {
            let images = try loadPNGs(in: atlas)
            for (name, image) in images {
                if image.opaquePixelCount == 0 {
                    failures.append(.init(file: name, reason: .frameEmpty))
                    continue
                }
                if name.hasPrefix("terrain-"), !isTerrainObject(name) {
                    failures += terrainFailures(name, image)
                }
                if isIncoherent(name, image, in: images, maxDistance: coherenceMaxDistance) {
                    failures.append(.init(file: name, reason: .frameIncoherent))
                }
                if isMisaligned(name, in: images, sweptEdge: catalog.entry(forSprite: name)?.sweptEdge) {
                    failures.append(.init(file: name, reason: .frameMisaligned))
                }
                if isBuildingBase(name), let bounds = image.opaqueBounds, bounds.maxY < image.height - 2 {
                    failures.append(.init(file: name, reason: .notGrounded))
                }
            }
            failures += KitRules.failures(images: images, catalog: catalog)
        }
        return failures.sorted { ($0.file, $0.reason.rawValue) < ($1.file, $1.reason.rawValue) }
    }

    /// Trees and outcrops (`terrain-forest-dense-v1`, change `terrain-v2`) stand over their tile
    /// instead of filling its diamond, and their variants are different objects, so neither the
    /// diamond rules nor frame coherence apply to them.
    /// The whole name must read `terrain-<forest|mountain>-<density>[-<autumn|winter>][-v<n>]`. `single`
    /// stays until the meadow-tree sprites leave the atlas.
    public static func isTerrainObject(_ fileName: String) -> Bool {
        SpriteFile(fileName).stem.wholeMatch(of: terrainObjectName) != nil
    }

    private nonisolated(unsafe) static let terrainObjectName =
        /terrain-(forest|mountain)-(single|sparse|medium|dense|peak)(-(autumn|winter))?(-v\d+)?/

    /// No transparent pixel inside the diamond, and nothing opaque beyond its 1-point bleed.
    static func terrainFailures(_ name: String, _ image: RGBAImage) -> [Failure] {
        let fill = DiamondFill(of: image, bleedPoints: 1, scale: SpriteFile(name).scale)
        var failures: [Failure] = []
        if fill.holes > 0 {
            failures.append(.init(file: name, reason: .terrainCoverageBelowThreshold))
        }
        if fill.beyondBleed > 0 {
            failures.append(.init(file: name, reason: .terrainOutsideDiamond))
        }
        return failures
    }

    /// Entry point shared by the `sprite-content-gate` executable and
    /// tests: `<resources-dir> [--max-distance <d>]`. Without the flag
    /// the threshold is read from `Sprites.style/pipeline.toml`.
    public static func run(arguments: [String]) throws -> Report {
        guard let rootPath = arguments.first else {
            return Report(exitCode: 2, output: "usage: sprite-content-gate <resources-dir> [--max-distance <d>]\n")
        }
        let root = URL(fileURLWithPath: rootPath)
        guard let distance = try flagDistance(arguments) ?? pinnedCoherenceDistance(resourcesRoot: root) else {
            return Report(exitCode: 2, output: "coherence_max_distance missing from Sprites.style/pipeline.toml\n")
        }
        let failures = try inspect(resourcesRoot: root, coherenceMaxDistance: distance)
        let lines = failures.map { "\($0.file) \($0.reason.rawValue)\n" }.joined()
        if failures.isEmpty {
            return Report(exitCode: 0, output: "[content-gate] all sprites pass\n")
        }
        return Report(exitCode: 1, output: lines + "[content-gate] \(failures.count) failure(s)\n")
    }

    /// The sprite a frame or variant must stay coherent with, or nil
    /// when the name is a base sprite or a construction stage.
    /// - `terrain-water-2` → `terrain-water`
    /// - `terrain-mountain-v1` → `terrain-mountain`
    /// - `building-sawmill-operational-0` → `building-sawmill`
    static func coherenceBase(for fileName: String) -> String? {
        let file = SpriteFile(fileName)
        let stem = file.stem
        guard let dash = stem.lastIndex(of: "-") else { return nil }
        var suffix = stem[stem.index(after: dash)...]
        if suffix.hasPrefix("v") {
            suffix = suffix.dropFirst()
        }
        guard !suffix.isEmpty, suffix.allSatisfy(\.isNumber) else { return nil }
        var base = String(stem[..<dash])
        if base.hasSuffix("-constructing") {
            return nil
        }
        if base.hasSuffix("-operational") {
            base.removeLast("-operational".count)
        }
        return file.sibling(base)
    }

    private static func isIncoherent(
        _ name: String,
        _ image: RGBAImage,
        in images: [String: RGBAImage],
        maxDistance: Double
    ) -> Bool {
        // A clump's variants are different trees (a bare oak beside a snowy spruce), not frames.
        guard !isTerrainObject(name), let baseName = coherenceBase(for: name), let base = images[baseName],
              base.opaquePixelCount > 0
        else { return false }
        return PaletteHistogram(of: image).distance(to: PaletteHistogram(of: base)) > maxDistance
    }

    /// A moving part (sails, wheel) changes the frame's extent on the edge it sweeps, so that edge
    /// is exempt; the bottom edge must always match.
    private static func isMisaligned(_ name: String, in images: [String: RGBAImage], sweptEdge: GateCatalog.Edge?) -> Bool {
        guard name.contains("-operational-"), let baseName = coherenceBase(for: name),
              let frameBox = images[name]?.opaqueBounds, let baseBox = images[baseName]?.opaqueBounds
        else { return false }
        let tolerance = silhouetteTolerance * SpriteFile(name).scale
        return (sweptEdge != .left && abs(frameBox.minX - baseBox.minX) > tolerance)
            || (sweptEdge != .right && abs(frameBox.maxX - baseBox.maxX) > tolerance)
            || abs(frameBox.maxY - baseBox.maxY) > tolerance
    }

    /// `building-<kind>.png` or `building-<kind>-<n|e|s|w>.png` at any scale; roads,
    /// construction stages, operational frames and variants excluded.
    static func isBuildingBase(_ fileName: String) -> Bool {
        let stem = SpriteFile(fileName).stem
        guard stem.hasPrefix("building-"), !stem.hasPrefix("building-road") else { return false }
        return coherenceBase(for: fileName) == nil && !stem.contains("-constructing-")
    }

    private static func flagDistance(_ arguments: [String]) -> Double? {
        guard let flag = arguments.firstIndex(of: "--max-distance"), flag + 1 < arguments.count else { return nil }
        return Double(arguments[flag + 1])
    }

    static func pinnedCoherenceDistance(resourcesRoot: URL) throws -> Double? {
        let toml = resourcesRoot.appendingPathComponent("Sprites.style/pipeline.toml")
        guard FileManager.default.fileExists(atPath: toml.path) else { return nil }
        for line in try String(contentsOf: toml, encoding: .utf8).split(separator: "\n") {
            let parts = line.split(separator: "=", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespaces) }
            if parts.count == 2, parts[0] == "coherence_max_distance" {
                return Double(parts[1])
            }
        }
        return nil
    }

    private static func atlasDirectories(in root: URL) throws -> [URL] {
        try FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "atlas" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    private static func loadPNGs(in atlas: URL) throws -> [String: RGBAImage] {
        var images: [String: RGBAImage] = [:]
        let files = try FileManager.default.contentsOfDirectory(at: atlas, includingPropertiesForKeys: nil)
        for file in files where file.pathExtension == "png" {
            images[file.lastPathComponent] = try RGBAImage(contentsOf: file)
        }
        return images
    }
}

/// Straight (non-premultiplied) RGBA8 pixels, row-major.
public struct RGBAImage: Sendable {
    public let width: Int
    public let height: Int
    public let rgba: [UInt8]

    public init(width: Int, height: Int, rgba: [UInt8]) {
        precondition(rgba.count == width * height * 4)
        self.width = width
        self.height = height
        self.rgba = rgba
    }

    public init(contentsOf url: URL) throws {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let cg = CGImageSourceCreateImageAtIndex(source, 0, nil)
        else {
            throw CocoaError(.fileReadCorruptFile, userInfo: [NSFilePathErrorKey: url.path])
        }
        let width = cg.width
        let height = cg.height
        var bytes = [UInt8](repeating: 0, count: width * height * 4)
        let drawn = bytes.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = CGContext(
                data: buffer.baseAddress,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: width * 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            )
            else { return false }
            context.draw(cg, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        guard drawn else { throw CocoaError(.fileReadCorruptFile, userInfo: [NSFilePathErrorKey: url.path]) }
        self.init(width: width, height: height, rgba: Self.unpremultiplied(bytes))
    }

    /// Alpha at or above this counts as opaque, matching the pipeline's
    /// soft-alpha threshold.
    public static let opaqueAlpha: UInt8 = 128

    public func alpha(x: Int, y: Int) -> UInt8 {
        rgba[(y * width + x) * 4 + 3]
    }

    /// Inclusive pixel bounds of the opaque region, or nil when empty.
    public var opaqueBounds: PixelBounds? {
        var bounds: PixelBounds?
        for y in 0 ..< height {
            for x in 0 ..< width where alpha(x: x, y: y) >= Self.opaqueAlpha {
                bounds = bounds?.including(x: x, y: y) ?? PixelBounds(minX: x, minY: y, maxX: x, maxY: y)
            }
        }
        return bounds
    }

    public var opaquePixelCount: Int {
        stride(from: 3, to: rgba.count, by: 4).reduce(0) { $0 + (rgba[$1] >= Self.opaqueAlpha ? 1 : 0) }
    }

    private static func unpremultiplied(_ bytes: [UInt8]) -> [UInt8] {
        var out = bytes
        for offset in stride(from: 0, to: out.count, by: 4) {
            let alpha = Int(out[offset + 3])
            guard alpha > 0, alpha < 255 else { continue }
            for channel in offset ..< offset + 3 {
                out[channel] = UInt8(min(255, Int(out[channel]) * 255 / alpha))
            }
        }
        return out
    }
}

public struct PixelBounds: Equatable, Sendable {
    public let minX: Int
    public let minY: Int
    public let maxX: Int
    public let maxY: Int

    func including(x: Int, y: Int) -> PixelBounds {
        PixelBounds(minX: min(minX, x), minY: min(minY, y), maxX: max(maxX, x), maxY: max(maxY, y))
    }
}

/// The iso diamond inscribed in a `width × height` tile canvas.
public enum DiamondMask {
    public static func contains(x: Int, y: Int, width: Int, height: Int) -> Bool {
        let dx = abs((Double(x) + 0.5) - Double(width) / 2) / (Double(width) / 2)
        let dy = abs((Double(y) + 0.5) - Double(height) / 2) / (Double(height) / 2)
        return dx + dy <= 1
    }
}

/// How a terrain tile fills its diamond. Tiles bleed up to `bleedPoints` past the exact diamond
/// so neighbours overlap: exact diamonds leave stair gaps, and linear filtering samples past them.
public struct DiamondFill: Sendable {
    /// Transparent pixels whose centre lies inside the diamond.
    public let holes: Int
    /// Opaque pixels beyond the diamond grown by the bleed (2 px across and 1 px down per point).
    public let beyondBleed: Int

    public init(of image: RGBAImage, bleedPoints: Int, scale: Int) {
        let halfWidth = Double(image.width) / 2, halfHeight = Double(image.height) / 2
        let grownWidth = halfWidth + Double(2 * bleedPoints * scale), grownHeight = halfHeight + Double(bleedPoints * scale)
        var holes = 0, beyond = 0
        for y in 0 ..< image.height {
            for x in 0 ..< image.width {
                let opaque = image.alpha(x: x, y: y) >= RGBAImage.opaqueAlpha
                let dx = abs(Double(x) + 0.5 - halfWidth), dy = abs(Double(y) + 0.5 - halfHeight)
                if dx / halfWidth + dy / halfHeight <= 1 {
                    if !opaque { holes += 1 }
                } else if opaque, dx / grownWidth + dy / grownHeight > 1 {
                    beyond += 1
                }
            }
        }
        self.holes = holes
        beyondBleed = beyond
    }
}

/// Normalised 16-bin histogram over opaque pixels: 4 luminance bands ×
/// 4 hue sectors. Low-saturation pixels fall into hue sector 0.
public struct PaletteHistogram: Sendable {
    public let bins: [Double]

    public init(of image: RGBAImage) {
        var counts = [Double](repeating: 0, count: 16)
        var total = 0.0
        let bytes = image.rgba
        for offset in stride(from: 0, to: bytes.count, by: 4) where bytes[offset + 3] >= RGBAImage.opaqueAlpha {
            let color = Color(
                red: Double(bytes[offset]) / 255,
                green: Double(bytes[offset + 1]) / 255,
                blue: Double(bytes[offset + 2]) / 255
            )
            counts[color.luminanceBand * 4 + color.hueSector] += 1
            total += 1
        }
        bins = total == 0 ? counts : counts.map { $0 / total }
    }

    /// Chi-squared distance in [0, 1]; 0 means identical distributions.
    public func distance(to other: PaletteHistogram) -> Double {
        var sum = 0.0
        for (lhs, rhs) in zip(bins, other.bins) where lhs + rhs > 0 {
            sum += (lhs - rhs) * (lhs - rhs) / (lhs + rhs)
        }
        return sum / 2
    }

    private struct Color {
        let red: Double
        let green: Double
        let blue: Double

        var luminanceBand: Int {
            min(3, Int((0.299 * red + 0.587 * green + 0.114 * blue) * 4))
        }

        /// 0: greys; 1: reds, browns and magentas; 2: yellows and
        /// greens; 3: cyans and blues.
        var hueSector: Int {
            let maxC = max(red, green, blue)
            let delta = maxC - min(red, green, blue)
            guard maxC > 0, delta / maxC >= 0.2 else { return 0 }
            var hue: Double = if maxC == red {
                (green - blue) / delta
            } else if maxC == green {
                2 + (blue - red) / delta
            } else {
                4 + (red - green) / delta
            }
            hue = (hue * 60).truncatingRemainder(dividingBy: 360)
            if hue < 0 {
                hue += 360
            }
            switch hue {
            case 45 ..< 165: return 2
            case 165 ..< 255: return 3
            default: return 1
            }
        }
    }
}
#endif
