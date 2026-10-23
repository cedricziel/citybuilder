// isokit: deterministic procedural textures and PBR finishes.
import AppKit
import SceneKit

struct Rng {
    var state: UInt64
    mutating func next() -> CGFloat {
        state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
        return CGFloat(state >> 33) / CGFloat(UInt64(1) << 31)
    }

    /// Uniform in [-amount/2, amount/2].
    mutating func jitter(_ amount: CGFloat) -> CGFloat {
        (next() - 0.5) * amount
    }
}

struct RGB {
    let red: CGFloat, green: CGFloat, blue: CGFloat
    init(_ red: CGFloat, _ green: CGFloat, _ blue: CGFloat) {
        self.red = red
        self.green = green
        self.blue = blue
    }

    func shifted(_ amount: CGFloat) -> RGB {
        RGB(red + amount, green + amount, blue + amount * 0.8)
    }
}

enum Tex {
    static let size = 128

    static func bitmap(seed: UInt64, _ draw: (CGContext, inout Rng) -> Void) -> CGImage {
        let ctx = CGContext(
            data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )
        guard let ctx else { fatalError("CGContext") }
        var rng = Rng(state: seed)
        draw(ctx, &rng)
        guard let image = ctx.makeImage() else { fatalError("makeImage") }
        return image
    }

    static func fill(_ ctx: CGContext, _ colour: RGB, _ rect: CGRect) {
        ctx.setFillColor(red: colour.red, green: colour.green, blue: colour.blue, alpha: 1)
        ctx.fill(rect)
    }

    static func speckled(_ base: RGB, amount: CGFloat, seed: UInt64) -> CGImage {
        bitmap(seed: seed) { ctx, rng in
            fill(ctx, base, CGRect(x: 0, y: 0, width: size, height: size))
            for _ in 0 ..< 1400 {
                let rect = CGRect(x: rng.next() * 128, y: rng.next() * 128, width: 2, height: 2)
                fill(ctx, base.shifted(rng.jitter(amount)), rect)
            }
        }
    }

    /// Vertical boards with dark joints and grain.
    static func planks(_ base: RGB, seed: UInt64) -> CGImage {
        bitmap(seed: seed) { ctx, rng in
            for board in 0 ..< 8 {
                let colour = base.shifted(rng.jitter(0.12))
                fill(ctx, colour, CGRect(x: board * 16, y: 0, width: 16, height: size))
                for _ in 0 ..< 6 {
                    let rect = CGRect(
                        x: CGFloat(board * 16) + 2 + rng.next() * 12,
                        y: rng.next() * 100,
                        width: 1,
                        height: 10 + rng.next() * 20
                    )
                    fill(ctx, colour.shifted(-0.06), rect)
                }
                fill(ctx, base.shifted(-0.28), CGRect(x: board * 16, y: 0, width: 2, height: size))
            }
        }
    }

    /// Courses of blocks (ashlar) or staggered roof tiles; rows run along texture x.
    static func courses(_ base: RGB, rowHeight: Int, blockWidth: Int, joint: RGB, seed: UInt64) -> CGImage {
        bitmap(seed: seed) { ctx, rng in
            // Round up: a row height that doesn't divide the texture would leave a bare band that
            // shows as a pale stripe wherever the texture repeats.
            for row in 0 ..< (size + rowHeight - 1) / rowHeight {
                let offset = row % 2 == 0 ? 0 : blockWidth / 2
                for col in -1 ... size / blockWidth {
                    let rect = CGRect(x: col * blockWidth + offset, y: row * rowHeight, width: blockWidth - 1, height: rowHeight)
                    fill(ctx, base.shifted(rng.jitter(0.12)), rect)
                }
                fill(ctx, joint, CGRect(x: 0, y: row * rowHeight, width: size, height: 2))
            }
        }
    }

    /// Straw: streaks down the slope (texture y) and darker course bands.
    static func thatch(_ straw: RGB, seed: UInt64) -> CGImage {
        bitmap(seed: seed) { ctx, rng in
            fill(ctx, straw, CGRect(x: 0, y: 0, width: size, height: size))
            for _ in 0 ..< 900 {
                let rect = CGRect(x: rng.next() * 128, y: rng.next() * 128, width: 1, height: 5 + rng.next() * 9)
                fill(ctx, straw.shifted(rng.jitter(0.3)), rect)
            }
            for band in 0 ..< 4 {
                fill(ctx, straw.shifted(-0.2), CGRect(x: 0, y: band * 32, width: size, height: 3))
            }
        }
    }

    static func cobble(seed: UInt64) -> CGImage {
        let stone = RGB(0.71, 0.61, 0.47)
        return bitmap(seed: seed) { ctx, rng in
            fill(ctx, stone.shifted(-0.25), CGRect(x: 0, y: 0, width: size, height: size))
            for row in 0 ..< 11 {
                for col in 0 ..< 11 {
                    let rect = CGRect(
                        x: CGFloat(col) * 11.6 + rng.next() * 2,
                        y: CGFloat(row) * 11.6 + rng.next() * 2,
                        width: 9.5,
                        height: 9.5
                    )
                    let colour = stone.shifted(rng.jitter(0.16))
                    ctx.setFillColor(red: colour.red, green: colour.green, blue: colour.blue, alpha: 1)
                    ctx.addPath(CGPath(roundedRect: rect, cornerWidth: 3, cornerHeight: 3, transform: nil))
                    ctx.fillPath()
                }
            }
        }
    }

    static let plaster = speckled(RGB(0.93, 0.80, 0.60), amount: 0.08, seed: 1)
    static let plasterPale = speckled(RGB(0.96, 0.90, 0.78), amount: 0.06, seed: 11)
    static let timber = speckled(RGB(0.33, 0.18, 0.09), amount: 0.06, seed: 2)
    static let rubble = speckled(RGB(0.63, 0.55, 0.45), amount: 0.18, seed: 3)
    static let ashlar = courses(RGB(0.76, 0.65, 0.50), rowHeight: 16, blockWidth: 32, joint: RGB(0.52, 0.44, 0.34), seed: 5)
    static let planks = planks(RGB(0.58, 0.38, 0.20), seed: 4)
    static let thatchStraw = thatch(RGB(0.55, 0.47, 0.35), seed: 6)
    /// The eave course: older straw, weathered darker and greyer than the slope above it.
    static let thatchEave = thatch(RGB(0.38, 0.35, 0.30), seed: 13)
    static let tile = courses(RGB(0.60, 0.26, 0.17), rowHeight: 16, blockWidth: 16, joint: RGB(0.28, 0.11, 0.07), seed: 7)
    static let slate = courses(RGB(0.31, 0.35, 0.45), rowHeight: 12, blockWidth: 14, joint: RGB(0.16, 0.18, 0.24), seed: 8)
    static let cobbles = cobble(seed: 9)
    static let wood = speckled(RGB(0.60, 0.39, 0.20), amount: 0.1, seed: 10)
    /// Trodden earth with grass: the building plot under every footprint.
    static let yard = speckled(RGB(0.47, 0.46, 0.29), amount: 0.16, seed: 12)
    /// Weathered grey bedrock for outcrops and mines; cool, so the warm sun leaves it grey.
    static let rock = speckled(RGB(0.42, 0.43, 0.46), amount: 0.25, seed: 14)
    /// Ripe grain: the straw texture in a lighter, golden tone.
    static let wheat = thatch(RGB(0.72, 0.60, 0.36), seed: 15)
    /// Weathered red brick for workshops, engine houses and halls.
    static let brick = courses(RGB(0.58, 0.30, 0.22), rowHeight: 8, blockWidth: 16, joint: RGB(0.62, 0.56, 0.48), seed: 16)
}

/// A finish = texture + PBR response. `repeatU/V` = texture repeats across the face.
public enum Finish {
    case plaster, plasterPale, timber, rubble, ashlar, planks, thatch, thatchEave, tile, slate, cobbles, wood, yard, rock, wheat, brick
    /// Window panes: dark glass, and the blue glass bands of modern houses. Day sprites never glow;
    /// window light comes only from the night-lights masks.
    case paint(NSColor), glass, glazing

    var roughness: CGFloat {
        switch self {
        case .glass: 0.2
        case .tile, .slate: 0.65
        case .timber, .wood, .planks: 0.8
        default: 0.92
        }
    }

    var contents: Any {
        switch self {
        case .plaster: Tex.plaster
        case .plasterPale: Tex.plasterPale
        case .timber: Tex.timber
        case .rubble: Tex.rubble
        case .ashlar: Tex.ashlar
        case .planks: Tex.planks
        case .thatch: Tex.thatchStraw
        case .thatchEave: Tex.thatchEave
        case .tile: Tex.tile
        case .slate: Tex.slate
        case .cobbles: Tex.cobbles
        case .wood: Tex.wood
        case .yard: Tex.yard
        case .rock: Tex.rock
        case .wheat: Tex.wheat
        case .brick: Tex.brick
        case let .paint(colour): colour
        case .glass: NSColor(red: 0.10, green: 0.12, blue: 0.16, alpha: 1)
        case .glazing: NSColor(red: 0.34, green: 0.50, blue: 0.62, alpha: 1)
        }
    }

    /// Roofs on an SCNBox slab: box faces map u down the slope, so rotate 90 deg to run courses along the ridge.
    func material(repeatU: CGFloat = 1, repeatV: CGFloat = 1, rotated: Bool = false) -> SCNMaterial {
        let material = SCNMaterial()
        material.name = Self.namePrefix + "\(self)"
        material.lightingModel = .physicallyBased
        material.diffuse.contents = contents
        material.diffuse.wrapS = .repeat
        material.diffuse.wrapT = .repeat
        let scale = SCNMatrix4MakeScale(max(repeatU, 0.25), max(repeatV, 0.25), 1)
        material.diffuse.contentsTransform = rotated ? SCNMatrix4Mult(SCNMatrix4MakeRotation(.pi / 2, 0, 0, 1), scale) : scale
        material.roughness.contents = roughness
        material.metalness.contents = 0.0
        return material
    }

    static let namePrefix = "finish:"

    /// True for the window-pane finishes, which glow in a recipe's night lights.
    static func isPane(_ material: SCNMaterial) -> Bool {
        [glass, glazing].contains { material.name == namePrefix + "\($0)" }
    }

    /// True when `material` came from the shared finish set (recipes may not define their own).
    static func isShared(_ material: SCNMaterial) -> Bool {
        material.name?.hasPrefix(namePrefix) == true && material.lightingModel == .physicallyBased
    }
}
