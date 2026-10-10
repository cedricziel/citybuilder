#!/usr/bin/env swift
// scripts/generate-app-icon.swift
//
// Composes the app icon from the existing in-game pixel-art sprites
// (Resources/Terrain.atlas/* and Resources/Buildings.atlas/*). The icon
// is a tiny isometric island vignette — a few grass tiles with a beach
// trim and water surround, two buildings on the grass, one forest tile.
//
// The whole composition is drawn at 256x256 native pixels, then upscaled
// 4x to 1024x1024 with nearest-neighbor sampling so the pixel-art look
// of the in-game sprites is preserved at icon scale.
//
// Outputs:
//   Apps/CitybuilderiOS/Assets.xcassets/AppIcon.appiconset/icon-1024.png
//   Apps/CitybuilderMac/Assets.xcassets/AppIcon.appiconset/icon-1024.png
//                                       (with ~10% transparent inset)
//
// Run from repo root:
//   swift scripts/generate-app-icon.swift

import AppKit
import Foundation

// MARK: - Pixmap (lifted from generate-sprites.swift for self-containment)

struct PColor: Equatable {
    let r: UInt8, g: UInt8, b: UInt8, a: UInt8
    init(_ r: Int, _ g: Int, _ b: Int, _ a: Int = 255) {
        self.r = UInt8(clamping: r)
        self.g = UInt8(clamping: g)
        self.b = UInt8(clamping: b)
        self.a = UInt8(clamping: a)
    }

    static let clear = PColor(0, 0, 0, 0)
}

final class Pixmap {
    let width: Int
    let height: Int
    var pixels: [PColor]

    init(width: Int, height: Int, fill: PColor = .clear) {
        self.width = width
        self.height = height
        self.pixels = Array(repeating: fill, count: width * height)
    }

    func set(_ x: Int, _ y: Int, _ color: PColor) {
        guard x >= 0, x < width, y >= 0, y < height else { return }
        pixels[y * width + x] = color
    }

    func get(_ x: Int, _ y: Int) -> PColor {
        guard x >= 0, x < width, y >= 0, y < height else { return .clear }
        return pixels[y * width + x]
    }

    /// Blit `src` onto self with its top-left at `(dx, dy)`. Source
    /// pixels with alpha == 0 are skipped (transparent passes through).
    func blit(_ src: Pixmap, atX dx: Int, atY dy: Int) {
        for y in 0 ..< src.height {
            for x in 0 ..< src.width {
                let c = src.get(x, y)
                if c.a == 0 { continue }
                set(dx + x, dy + y, c)
            }
        }
    }

    /// `opaque` drops the alpha channel: App Store Connect rejects an iOS
    /// marketing icon that has one, even when every pixel is opaque.
    func savePNG(to path: String, opaque: Bool = false) {
        var raw = [UInt8](repeating: 0, count: width * height * 4)
        for i in 0 ..< (width * height) {
            raw[i * 4 + 0] = pixels[i].r
            raw[i * 4 + 1] = pixels[i].g
            raw[i * 4 + 2] = pixels[i].b
            raw[i * 4 + 3] = pixels[i].a
        }
        let data = Data(raw)
        let provider = CGDataProvider(data: data as CFData)!
        let cs = CGColorSpaceCreateDeviceRGB()
        let alpha: CGImageAlphaInfo = opaque ? .noneSkipLast : .last
        let bitmap = CGBitmapInfo(rawValue: alpha.rawValue)
        guard let img = CGImage(
            width: width, height: height,
            bitsPerComponent: 8, bitsPerPixel: 32,
            bytesPerRow: width * 4,
            space: cs,
            bitmapInfo: bitmap,
            provider: provider,
            decode: nil,
            shouldInterpolate: false,
            intent: .defaultIntent
        )
        else { fatalError("CGImage creation failed for \(path)") }
        let rep = NSBitmapImageRep(cgImage: img)
        guard let pngData = rep.representation(using: .png, properties: [:]) else {
            fatalError("PNG encode failed for \(path)")
        }
        try? FileManager.default.createDirectory(
            atPath: (path as NSString).deletingLastPathComponent,
            withIntermediateDirectories: true
        )
        try? pngData.write(to: URL(fileURLWithPath: path))
        print("  wrote \(path) (\(width)x\(height))")
    }
}

// MARK: - Load existing PNG sprites

func loadPNG(_ path: String) -> Pixmap {
    guard let img = NSImage(contentsOfFile: path),
          let tiff = img.tiffRepresentation,
          let rep = NSBitmapImageRep(data: tiff)
    else { fatalError("could not load \(path)") }

    let w = Int(rep.pixelsWide)
    let h = Int(rep.pixelsHigh)
    let result = Pixmap(width: w, height: h)
    guard let cg = rep.cgImage else { fatalError("no CGImage for \(path)") }

    // Re-render into our RGBA8 buffer via a context — handles whatever
    // pixel format the source PNG used.
    var raw = [UInt8](repeating: 0, count: w * h * 4)
    let cs = CGColorSpaceCreateDeviceRGB()
    let info = CGImageAlphaInfo.premultipliedLast.rawValue
    guard let ctx = CGContext(
        data: &raw,
        width: w, height: h,
        bitsPerComponent: 8,
        bytesPerRow: w * 4,
        space: cs,
        bitmapInfo: info
    ) else { fatalError("context for \(path)") }
    ctx.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h))

    // CGContext bitmap buffer is row-major top-to-bottom and matches the
    // Pixmap layout directly — no Y flip needed.
    for y in 0 ..< h {
        for x in 0 ..< w {
            let j = (y * w + x) * 4
            let a = raw[j + 3]
            let r: UInt8 = a == 0 ? 0 : UInt8(min(255, Int(raw[j]) * 255 / Int(a)))
            let g: UInt8 = a == 0 ? 0 : UInt8(min(255, Int(raw[j + 1]) * 255 / Int(a)))
            let b: UInt8 = a == 0 ? 0 : UInt8(min(255, Int(raw[j + 2]) * 255 / Int(a)))
            result.pixels[y * w + x] = PColor(Int(r), Int(g), Int(b), Int(a))
        }
    }
    return result
}

// MARK: - Upscaling

/// Horizontal mirror — flips a sprite around its vertical axis so a
/// building facing front-right now faces front-left (the iso analog of
/// rotating the structure 180° about its vertical).
func mirroredX(_ src: Pixmap) -> Pixmap {
    let out = Pixmap(width: src.width, height: src.height)
    for y in 0 ..< src.height {
        for x in 0 ..< src.width {
            out.set(src.width - 1 - x, y, src.get(x, y))
        }
    }
    return out
}

/// Nearest-neighbor upscale by integer factor.
func upscale(_ src: Pixmap, factor: Int) -> Pixmap {
    let out = Pixmap(width: src.width * factor, height: src.height * factor)
    for y in 0 ..< out.height {
        for x in 0 ..< out.width {
            let sx = x / factor
            let sy = y / factor
            out.set(x, y, src.get(sx, sy))
        }
    }
    return out
}

// MARK: - Compose the icon

let repoRoot = FileManager.default.currentDirectoryPath

func sprite(_ subpath: String) -> Pixmap {
    loadPNG("\(repoRoot)/\(subpath)")
}

// Background fill — dark navy so the icon pops in dock / home screen.
let navy = PColor(0x1a, 0x24, 0x38)
let canvas = Pixmap(width: 256, height: 256, fill: navy)

// Standard in-game tile dimensions.
let tileW = 64
let tileH = 32

// Convert tile (col, row) coordinates centered around (cx, cy) into the
// top-left origin of that tile's 64x32 bounding box on the 256x256 canvas.
let centerX = 128
let centerY = 128 - 16 // shift up a touch so the buildings have headroom

func tileOrigin(col: Int, row: Int, cx: Int, cy: Int) -> (x: Int, y: Int) {
    let sx = centerX + (col - cx) * (tileW / 2) - (row - cy) * (tileW / 2) - tileW / 2
    let sy = centerY + (col - cx) * (tileH / 2) + (row - cy) * (tileH / 2)
    return (sx, sy)
}

// Layout — a 3x3 grass island with beach edge, on a water ring.
// (col, row) coordinates use the standard iso grid.
//
//         (-1,-1)  (0,-1)   (1,-1)
//    (-1,0)  (0,0)  (1,0)   (2,0)
// (-1,1) (0,1) (1,1) (2,1)  (3,1)
//    (0,2)  (1,2)  (2,2)
//         (1,3)  (2,3)

let grass = sprite("Resources/Terrain.atlas/terrain-grass.png")
let water = sprite("Resources/Terrain.atlas/terrain-water.png")
let beach = sprite("Resources/Terrain.atlas/terrain-beach.png")
let forest = sprite("Resources/Terrain.atlas/terrain-forest.png")
let house = sprite("Resources/Buildings.atlas/building-house.png")
let sawmill = sprite("Resources/Buildings.atlas/building-sawmill.png")
let lumberjack = sprite("Resources/Buildings.atlas/building-lumberjack-hut.png")

func place(_ s: Pixmap, col: Int, row: Int) {
    let (x, y) = tileOrigin(col: col, row: row, cx: 1, cy: 1)
    canvas.blit(s, atX: x, atY: y)
}

func placeBuilding(_ s: Pixmap, anchorCol col: Int, anchorRow row: Int, footprintW fw: Int, footprintH fh: Int) {
    // The sprite is drawn so its bottom-center sits at the anchor tile's
    // top-center. The anchor tile bounding box's top-left is at tileOrigin;
    // top-center is +tileW/2 horizontally. The building canvas's bottom-
    // center anchors there. We compute the screen position for the
    // bottom-center, then back out the top-left of the building sprite.
    //
    // Multi-tile footprints anchor at (col, row) but visually cover an
    // fw x fh footprint; the bottom-center of the rendered sprite lines
    // up with the front-most tile's top-center. For our purposes the
    // building's footprint anchor is the same as the tile we name.
    let anchorScreenY = centerY + (col - 1) * (tileH / 2) + (row - 1) * (tileH / 2) + tileH / 2
    let anchorScreenX = centerX + (col - 1) * (tileW / 2) - (row - 1) * (tileW / 2)
    // Offset to align bottom-center of the building canvas with the
    // anchor tile's top-center; sprite is footprintW x footprintH tiles.
    let offsetX = (fw - fh) * tileW / 4
    let offsetY = -tileH / 2 * (2 * fh - 1)
    let topLeftX = anchorScreenX + offsetX - s.width / 2
    let topLeftY = anchorScreenY + offsetY - (s.height - tileH)
    canvas.blit(s, atX: topLeftX, atY: topLeftY)
}

// Water ring (back to front so closer tiles overpaint farther ones).
let waterTiles: [(Int, Int)] = [
    (-2, 0), (-1, -1), (0, -2), (1, -2), (2, -2), (3, -1), (3, 0),
    (-2, 1), (-2, 2), (3, 1), (3, 2),
    (-1, 3), (0, 3), (1, 3), (2, 3), (3, 3), (-2, 3),
    (0, 4), (1, 4), (2, 4)
]
for (c, r) in waterTiles { place(water, col: c, row: r) }

// Beach ring (just inside the water).
let beachTiles: [(Int, Int)] = [
    (-1, 0), (0, -1), (1, -1), (2, -1), (2, 0),
    (-1, 1), (2, 1),
    (-1, 2), (0, 2), (1, 2), (2, 2)
]
for (c, r) in beachTiles { place(beach, col: c, row: r) }

// Grass interior (3x3).
let grassTiles: [(Int, Int)] = [
    (0, 0), (1, 0),
    (0, 1), (1, 1),
    (0, 0), (1, 1)
]
for (c, r) in grassTiles { place(grass, col: c, row: r) }

// One forest tile at the back-right corner.
place(forest, col: 2, row: -1)
// And one front-left for variety.
place(forest, col: -1, row: 1)

// Buildings — order matters for occlusion. Back to front.
placeBuilding(lumberjack, anchorCol: 0, anchorRow: 0, footprintW: 1, footprintH: 1)
placeBuilding(sawmill, anchorCol: 1, anchorRow: 0, footprintW: 1, footprintH: 1)
placeBuilding(house, anchorCol: 1, anchorRow: 1, footprintW: 1, footprintH: 1)

// MARK: - Upscale to 1024x1024 with nearest-neighbor

let upscaled = upscale(canvas, factor: 4)

// MARK: - Mac variant: 10% transparent inset + all macOS icon sizes

func macInset(_ src: Pixmap, insetFraction: Double) -> Pixmap {
    let pad = Int(Double(src.width) * insetFraction)
    let innerW = src.width - 2 * pad
    let innerH = src.height - 2 * pad
    // First scale the source down to inner size with nearest-neighbor.
    let scaled = Pixmap(width: innerW, height: innerH)
    for y in 0 ..< innerH {
        for x in 0 ..< innerW {
            let sx = x * src.width / innerW
            let sy = y * src.height / innerH
            scaled.set(x, y, src.get(sx, sy))
        }
    }
    // Then center it on a transparent canvas at the original size.
    let out = Pixmap(width: src.width, height: src.height, fill: .clear)
    out.blit(scaled, atX: pad, atY: pad)
    return out
}

/// Resize via Core Graphics with high-quality interpolation so the
/// small Mac icon sizes (16, 32) stay legible instead of going to
/// pixel mush. Operates through a premultiplied-RGBA context.
func smoothResize(_ src: Pixmap, to size: Int) -> Pixmap {
    var srcBytes = [UInt8](repeating: 0, count: src.width * src.height * 4)
    for i in 0 ..< (src.width * src.height) {
        let p = src.pixels[i]
        let a = Int(p.a)
        srcBytes[i * 4 + 0] = UInt8(Int(p.r) * a / 255)
        srcBytes[i * 4 + 1] = UInt8(Int(p.g) * a / 255)
        srcBytes[i * 4 + 2] = UInt8(Int(p.b) * a / 255)
        srcBytes[i * 4 + 3] = p.a
    }
    let cs = CGColorSpaceCreateDeviceRGB()
    let info = CGImageAlphaInfo.premultipliedLast.rawValue
    guard let srcCtx = CGContext(
        data: &srcBytes,
        width: src.width, height: src.height,
        bitsPerComponent: 8,
        bytesPerRow: src.width * 4,
        space: cs,
        bitmapInfo: info
    ), let srcImg = srcCtx.makeImage()
    else { fatalError("source CGImage failed") }

    var dstBytes = [UInt8](repeating: 0, count: size * size * 4)
    guard let dstCtx = CGContext(
        data: &dstBytes,
        width: size, height: size,
        bitsPerComponent: 8,
        bytesPerRow: size * 4,
        space: cs,
        bitmapInfo: info
    ) else { fatalError("dest context failed") }
    dstCtx.interpolationQuality = .high
    dstCtx.draw(srcImg, in: CGRect(x: 0, y: 0, width: size, height: size))

    let out = Pixmap(width: size, height: size)
    for y in 0 ..< size {
        for x in 0 ..< size {
            let i = (y * size + x) * 4
            let a = dstBytes[i + 3]
            let r: UInt8 = a == 0 ? 0 : UInt8(min(255, Int(dstBytes[i]) * 255 / Int(a)))
            let g: UInt8 = a == 0 ? 0 : UInt8(min(255, Int(dstBytes[i + 1]) * 255 / Int(a)))
            let b: UInt8 = a == 0 ? 0 : UInt8(min(255, Int(dstBytes[i + 2]) * 255 / Int(a)))
            out.pixels[i / 4] = PColor(Int(r), Int(g), Int(b), Int(a))
        }
    }
    return out
}

let iOSIcon = upscaled
let macSource = macInset(upscaled, insetFraction: 0.10)

iOSIcon.savePNG(to: "\(repoRoot)/Apps/CitybuilderiOS/Assets.xcassets/AppIcon.appiconset/icon-1024.png", opaque: true)

// Emit the canonical macOS AppIcon size matrix. macOS does not support
// the single-source-image fallback that iOS 17+ does, so we provide
// every pixel size actool wants and let actool pick which slot each
// fills via the Contents.json scale/size entries.
let macSizes = [16, 32, 64, 128, 256, 512, 1024]
let macIconDir = "\(repoRoot)/Apps/CitybuilderMac/Assets.xcassets/AppIcon.appiconset"
for size in macSizes {
    let resized = smoothResize(macSource, to: size)
    resized.savePNG(to: "\(macIconDir)/icon-\(size).png")
}

// MARK: - Asset catalog Contents.json files

func writeJSON(_ json: String, to path: String) {
    try? FileManager.default.createDirectory(
        atPath: (path as NSString).deletingLastPathComponent,
        withIntermediateDirectories: true
    )
    try? json.write(toFile: path, atomically: true, encoding: .utf8)
    print("  wrote \(path)")
}

let iOSContents = """
{
  "images" : [
    {
      "filename" : "icon-1024.png",
      "idiom" : "universal",
      "platform" : "ios",
      "size" : "1024x1024"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
"""

let macContents = """
{
  "images" : [
    { "filename" : "icon-16.png",   "idiom" : "mac", "scale" : "1x", "size" : "16x16" },
    { "filename" : "icon-32.png",   "idiom" : "mac", "scale" : "2x", "size" : "16x16" },
    { "filename" : "icon-32.png",   "idiom" : "mac", "scale" : "1x", "size" : "32x32" },
    { "filename" : "icon-64.png",   "idiom" : "mac", "scale" : "2x", "size" : "32x32" },
    { "filename" : "icon-128.png",  "idiom" : "mac", "scale" : "1x", "size" : "128x128" },
    { "filename" : "icon-256.png",  "idiom" : "mac", "scale" : "2x", "size" : "128x128" },
    { "filename" : "icon-256.png",  "idiom" : "mac", "scale" : "1x", "size" : "256x256" },
    { "filename" : "icon-512.png",  "idiom" : "mac", "scale" : "2x", "size" : "256x256" },
    { "filename" : "icon-512.png",  "idiom" : "mac", "scale" : "1x", "size" : "512x512" },
    { "filename" : "icon-1024.png", "idiom" : "mac", "scale" : "2x", "size" : "512x512" }
  ],
  "info" : { "author" : "xcode", "version" : 1 }
}
"""

let rootContents = """
{
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
"""

writeJSON(iOSContents, to: "\(repoRoot)/Apps/CitybuilderiOS/Assets.xcassets/AppIcon.appiconset/Contents.json")
writeJSON(macContents, to: "\(repoRoot)/Apps/CitybuilderMac/Assets.xcassets/AppIcon.appiconset/Contents.json")
writeJSON(rootContents, to: "\(repoRoot)/Apps/CitybuilderiOS/Assets.xcassets/Contents.json")
writeJSON(rootContents, to: "\(repoRoot)/Apps/CitybuilderMac/Assets.xcassets/Contents.json")

print("done.")
