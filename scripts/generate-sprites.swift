#!/usr/bin/env swift
// scripts/generate-sprites.swift
//
// Procedurally generates "olden days" isometric pixel-art sprites for the
// MVP renderer. Inspired by Caesar III / Anno 1602 / SimCity 2000 — small
// palette, blocky pixels, strong outlines, simple cell-shaded surfaces.
//
// Output (run from repo root):
//   Resources/Sprites/terrain-<kind>.png   (64x32 each)
//   Resources/Sprites/building-<kind>.png  (footprint-dependent)
//
// Run via:
//   swift scripts/generate-sprites.swift

import AppKit
import Foundation

// MARK: - Tiny pixel canvas

struct Color: Equatable {
    let r: UInt8, g: UInt8, b: UInt8, a: UInt8
    init(_ r: Int, _ g: Int, _ b: Int, _ a: Int = 255) {
        self.r = UInt8(clamping: r); self.g = UInt8(clamping: g)
        self.b = UInt8(clamping: b); self.a = UInt8(clamping: a)
    }

    static let clear = Color(0, 0, 0, 0)
    func darker(_ amount: Int = 30) -> Color {
        Color(Int(r) - amount, Int(g) - amount, Int(b) - amount, Int(a))
    }

    func lighter(_ amount: Int = 30) -> Color {
        Color(Int(r) + amount, Int(g) + amount, Int(b) + amount, Int(a))
    }
}

final class Pixmap {
    let width: Int
    let height: Int
    var pixels: [Color]

    init(width: Int, height: Int) {
        self.width = width
        self.height = height
        self.pixels = Array(repeating: .clear, count: width * height)
    }

    func set(_ x: Int, _ y: Int, _ color: Color) {
        guard x >= 0, x < width, y >= 0, y < height else { return }
        pixels[y * width + x] = color
    }

    func get(_ x: Int, _ y: Int) -> Color {
        guard x >= 0, x < width, y >= 0, y < height else { return .clear }
        return pixels[y * width + x]
    }

    func fillRect(x: Int, y: Int, w: Int, h: Int, _ color: Color) {
        for dy in 0 ..< h {
            for dx in 0 ..< w {
                set(x + dx, y + dy, color)
            }
        }
    }

    func savePNG(to path: String) {
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
        let bitmap = CGBitmapInfo(rawValue: CGImageAlphaInfo.last.rawValue)
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
        try? pngData.write(to: URL(fileURLWithPath: path))
        print("  wrote \(path) (\(width)x\(height))")
    }
}

// MARK: - Iso primitives

/// Half-width of the iso diamond at vertical row `row` for a diamond of
/// width W = 2*H. Row 0 is the top, row H-1 is the bottom.
func halfWidth(row: Int, height tileHeight: Int) -> Int {
    let halfRow = min(row, tileHeight - 1 - row)
    return (halfRow + 1) * 2
}

/// Fill an iso diamond into `canvas` with its top-left corner at (originX, originY).
/// The diamond is `tileWidth × tileHeight` with the standard 2:1 iso ratio.
func drawIsoDiamond(
    _ canvas: Pixmap,
    originX: Int, originY: Int,
    width tileWidth: Int, height tileHeight: Int,
    fill: Color, edge: Color, highlight: Color? = nil
) {
    let centerX = originX + tileWidth / 2
    for row in 0 ..< tileHeight {
        let hw = halfWidth(row: row, height: tileHeight)
        let leftX = centerX - hw
        let rightX = centerX + hw - 1
        for x in leftX ... rightX {
            canvas.set(x, originY + row, fill)
        }
        // Edge pixels.
        canvas.set(leftX, originY + row, edge)
        canvas.set(rightX, originY + row, edge)
        if let highlight, row < tileHeight / 2 {
            // Upper-left + upper-right rim get a 1-pixel highlight.
            canvas.set(leftX + 1, originY + row, highlight)
        }
    }
}

/// Stipple a color into the diamond: every Nth pixel within the shape.
func stippleDiamond(
    _ canvas: Pixmap,
    originX: Int, originY: Int,
    width tileWidth: Int, height tileHeight: Int,
    color: Color, step: Int
) {
    let centerX = originX + tileWidth / 2
    var counter = 0
    for row in 0 ..< tileHeight {
        let hw = halfWidth(row: row, height: tileHeight)
        let leftX = centerX - hw + 1
        let rightX = centerX + hw - 2
        guard leftX <= rightX else { continue }
        for x in leftX ... rightX {
            counter += 1
            if counter % step == 0 { canvas.set(x, originY + row, color) }
        }
    }
}

// MARK: - Palettes (deliberately small + saturated, classic look)

enum P {
    // Terrain
    static let grass = Color(78, 142, 50)
    static let grassDark = Color(56, 110, 38)
    static let grassLight = Color(124, 184, 84)

    static let forest = Color(52, 102, 38)
    static let forestDark = Color(32, 70, 26)
    static let forestLight = Color(78, 138, 56)
    static let trunk = Color(72, 42, 22)

    static let beach = Color(220, 196, 132)
    static let beachDark = Color(184, 156, 100)
    static let beachLight = Color(244, 220, 168)

    static let water = Color(50, 90, 160)
    static let waterDark = Color(34, 64, 124)
    static let waterLight = Color(100, 148, 208)
    static let waterFoam = Color(220, 232, 248)

    static let mountain = Color(116, 116, 124)
    static let mountainDark = Color(80, 80, 88)
    static let mountainLight = Color(168, 168, 176)
    static let snow = Color(244, 248, 252)

    // Buildings
    static let woodWall = Color(168, 124, 70)
    static let woodWallDark = Color(120, 86, 44)
    static let woodWallLight = Color(204, 160, 100)
    static let stoneWall = Color(168, 156, 132)
    static let stoneWallDark = Color(120, 108, 84)
    static let stoneWallLight = Color(200, 188, 164)
    static let roofRed = Color(176, 60, 44)
    static let roofRedDark = Color(124, 40, 28)
    static let roofGrey = Color(96, 96, 104)
    static let roofGreyDark = Color(60, 60, 68)
    static let roofGold = Color(232, 180, 64)
    static let roofGoldDark = Color(176, 124, 36)
    static let windowYellow = Color(248, 224, 120)
    static let outline = Color(28, 22, 18)
    static let roadStone = Color(132, 128, 116)
    static let roadStoneDark = Color(96, 92, 80)
}

// MARK: - Terrain sprites (64x32)

func terrainCanvas() -> Pixmap {
    Pixmap(width: 64, height: 32)
}

func grassSprite() -> Pixmap {
    let p = terrainCanvas()
    drawIsoDiamond(
        p,
        originX: 0,
        originY: 0,
        width: 64,
        height: 32,
        fill: P.grass,
        edge: P.grassDark,
        highlight: P.grassLight
    )
    // Sparse grass tufts (darker pixels).
    stippleDiamond(
        p,
        originX: 0,
        originY: 0,
        width: 64,
        height: 32,
        color: P.grassDark,
        step: 13
    )
    // Light highlights.
    stippleDiamond(
        p,
        originX: 0,
        originY: 0,
        width: 64,
        height: 32,
        color: P.grassLight,
        step: 19
    )
    return p
}

func forestSprite() -> Pixmap {
    let p = terrainCanvas()
    // Base is darker than grass.
    drawIsoDiamond(
        p,
        originX: 0,
        originY: 0,
        width: 64,
        height: 32,
        fill: P.forest,
        edge: P.forestDark,
        highlight: P.forestLight
    )
    /// Three tree clusters: small triangular silhouettes.
    func drawTree(atX cx: Int, atY cy: Int) {
        // trunk
        p.set(cx, cy + 3, P.trunk)
        p.set(cx, cy + 4, P.trunk)
        // canopy (small triangle)
        for r in 0 ..< 4 {
            let w = 2 - abs(r - 1)
            for dx in -w ... w {
                p.set(cx + dx, cy - r + 2, r == 0 ? P.forestLight : P.forest)
            }
        }
        p.set(cx - 1, cy - 1, P.forestDark)
        p.set(cx + 1, cy - 1, P.forestDark)
    }
    drawTree(atX: 20, atY: 14)
    drawTree(atX: 44, atY: 14)
    drawTree(atX: 32, atY: 22)
    return p
}

func beachSprite() -> Pixmap {
    let p = terrainCanvas()
    drawIsoDiamond(
        p,
        originX: 0,
        originY: 0,
        width: 64,
        height: 32,
        fill: P.beach,
        edge: P.beachDark,
        highlight: P.beachLight
    )
    // A few pebble specks.
    stippleDiamond(
        p,
        originX: 0,
        originY: 0,
        width: 64,
        height: 32,
        color: P.beachDark,
        step: 17
    )
    return p
}

func waterSprite() -> Pixmap {
    let p = terrainCanvas()
    drawIsoDiamond(
        p,
        originX: 0,
        originY: 0,
        width: 64,
        height: 32,
        fill: P.water,
        edge: P.waterDark,
        highlight: P.waterLight
    )
    // Two foam ripples — pairs of lighter pixels in a wavy line.
    let ripple = [(20, 12), (24, 13), (28, 12), (32, 13), (36, 12), (40, 13), (44, 12)]
    for (x, y) in ripple {
        p.set(x, y, P.waterFoam)
    }
    let ripple2 = [(26, 20), (30, 21), (34, 20), (38, 21)]
    for (x, y) in ripple2 {
        p.set(x, y, P.waterFoam)
    }
    return p
}

func mountainSprite() -> Pixmap {
    let p = terrainCanvas()
    drawIsoDiamond(
        p,
        originX: 0,
        originY: 0,
        width: 64,
        height: 32,
        fill: P.mountain,
        edge: P.mountainDark,
        highlight: P.mountainLight
    )
    // Add a chunky rocky peak sitting on the diamond.
    let peakCenter = 32
    for r in 0 ..< 10 {
        let halfW = max(1, 6 - r / 2)
        let yy = 6 + r
        for dx in -halfW ... halfW {
            let color: Color = if r < 3 { P.snow }
            else if dx == -halfW || dx == halfW { P.mountainDark }
            else { (dx & 1 == 0) ? P.mountain : P.mountainLight }
            p.set(peakCenter + dx, yy, color)
        }
    }
    return p
}

// MARK: - Building sprites

/// Footprint diamond + extruded body + roof, drawn with the anchor at the
/// top-left tile of the footprint. Sprite height accommodates the building
/// rising above the tile. The renderer will offset the sprite so the
/// diamond base aligns to the iso anchor tile.
///
/// Sprite dimensions:
///   width  = footprint.width * 64
///   tile-h = footprint.height * 32     (the diamond base)
///   total-h = tile-h + bodyHeight + roofHeight
///
/// In scene-y-up, the sprite is rendered with its anchor at (0.5, 0) so
/// the diamond base sits at the tile position. We allocate extra height at
/// the TOP of the pixmap for the building body.
func buildingSprite(
    footprintW: Int, footprintH: Int,
    bodyHeight: Int, roofHeight: Int,
    wall: Color, wallDark: Color, wallLight: Color,
    roof: Color, roofDark: Color,
    showWindows: Bool = true
) -> Pixmap {
    let tileW = footprintW * 64
    let tileH = footprintH * 32
    let totalH = tileH + bodyHeight + roofHeight
    let p = Pixmap(width: tileW, height: totalH)
    // The diamond sits at the BOTTOM of the pixmap.
    let baseY = totalH - tileH
    drawIsoDiamond(
        p,
        originX: 0,
        originY: baseY,
        width: tileW,
        height: tileH,
        fill: wallDark,
        edge: P.outline,
        highlight: nil
    )
    // Compute the bounding box of the building body, centered horizontally
    // and sized to fit inside the diamond's widest row.
    let bodyW = max(4, tileW / 2)
    let bodyX = (tileW - bodyW) / 2
    let bodyTop = baseY - bodyHeight
    // Left wall (lighter)
    p.fillRect(x: bodyX, y: bodyTop, w: bodyW / 2, h: bodyHeight, wallLight)
    // Right wall (base color)
    p.fillRect(x: bodyX + bodyW / 2, y: bodyTop, w: bodyW / 2, h: bodyHeight, wall)
    // Outline the body.
    for dy in 0 ..< bodyHeight {
        p.set(bodyX, bodyTop + dy, P.outline)
        p.set(bodyX + bodyW - 1, bodyTop + dy, P.outline)
    }
    for dx in 0 ..< bodyW {
        p.set(bodyX + dx, bodyTop, P.outline)
    }
    // Vertical seam where the two wall faces meet.
    for dy in 0 ..< bodyHeight {
        p.set(bodyX + bodyW / 2, bodyTop + dy, wallDark)
    }
    // Windows.
    if showWindows, bodyHeight >= 6 {
        let winY = bodyTop + bodyHeight / 3
        let winSize = max(2, bodyHeight / 3)
        // Left face window
        p.fillRect(x: bodyX + 2, y: winY, w: winSize, h: winSize, P.windowYellow)
        // Right face window
        p.fillRect(x: bodyX + bodyW - 2 - winSize, y: winY, w: winSize, h: winSize, P.windowYellow)
    }
    // Roof — a pitched roof drawn as two trapezoids meeting at a ridge.
    let roofTop = bodyTop - roofHeight
    for r in 0 ..< roofHeight {
        let inset = (r * bodyW / 2) / max(1, roofHeight)
        let leftX = bodyX + inset
        let rightX = bodyX + bodyW - 1 - inset
        for x in leftX ... rightX {
            let onSeam = (x == bodyX + bodyW / 2)
            let color: Color = if x < bodyX + bodyW / 2 { roof }
            else { roofDark }
            p.set(x, roofTop + r, onSeam ? roofDark : color)
        }
        // Roof edge.
        p.set(leftX, roofTop + r, P.outline)
        p.set(rightX, roofTop + r, P.outline)
    }
    return p
}

func houseSprite() -> Pixmap {
    buildingSprite(
        footprintW: 2, footprintH: 2,
        bodyHeight: 20, roofHeight: 14,
        wall: P.woodWall, wallDark: P.woodWallDark, wallLight: P.woodWallLight,
        roof: P.roofRed, roofDark: P.roofRedDark
    )
}

func warehouseSprite() -> Pixmap {
    buildingSprite(
        footprintW: 3, footprintH: 3,
        bodyHeight: 28, roofHeight: 18,
        wall: P.stoneWall, wallDark: P.stoneWallDark, wallLight: P.stoneWallLight,
        roof: P.roofGrey, roofDark: P.roofGreyDark
    )
}

func lumberjackHutSprite() -> Pixmap {
    buildingSprite(
        footprintW: 2, footprintH: 2,
        bodyHeight: 16, roofHeight: 12,
        wall: P.woodWallDark, wallDark: Color(72, 50, 24),
        wallLight: P.woodWall,
        roof: P.forest, roofDark: P.forestDark
    )
}

func sawmillSprite() -> Pixmap {
    let p = buildingSprite(
        footprintW: 2, footprintH: 2,
        bodyHeight: 22, roofHeight: 14,
        wall: P.stoneWall, wallDark: P.stoneWallDark, wallLight: P.stoneWallLight,
        roof: P.woodWallDark, roofDark: Color(72, 50, 24)
    )
    // Add a small saw-blade circle in the front face center.
    let cx = p.width / 2 + 8
    let cy = p.height - 64 - 10
    for dy in -3 ... 3 {
        for dx in -3 ... 3 {
            if dx * dx + dy * dy <= 9 {
                p.set(cx + dx, cy + dy, P.roofGold)
            }
        }
    }
    return p
}

func townCenterSprite() -> Pixmap {
    let p = buildingSprite(
        footprintW: 3, footprintH: 3,
        bodyHeight: 36, roofHeight: 20,
        wall: P.stoneWallLight, wallDark: P.stoneWall, wallLight: Color(220, 212, 188),
        roof: P.roofGold, roofDark: P.roofGoldDark
    )
    // Add a flagpole on top.
    let cx = p.width / 2
    for dy in 0 ..< 12 {
        p.set(cx, dy, P.outline)
    }
    // Tiny flag.
    p.fillRect(x: cx + 1, y: 2, w: 6, h: 4, P.roofRed)
    p.set(cx + 7, 2, P.outline)
    p.set(cx + 7, 5, P.outline)
    return p
}

func roadSprite() -> Pixmap {
    let p = terrainCanvas()
    drawIsoDiamond(
        p,
        originX: 0,
        originY: 0,
        width: 64,
        height: 32,
        fill: P.roadStone,
        edge: P.roadStoneDark,
        highlight: P.roadStone.lighter(20)
    )
    // Cobble pattern: dots in a 4-pixel grid.
    let centerX = 32
    for row in 2 ..< 30 where row % 3 == 0 {
        let hw = halfWidth(row: row, height: 32)
        let leftX = centerX - hw + 2
        let rightX = centerX + hw - 2
        var x = leftX
        while x <= rightX {
            p.set(x, row, P.roadStoneDark)
            x += 4
        }
    }
    return p
}

// MARK: - Main

let cwd = FileManager.default.currentDirectoryPath
let outputDir = "\(cwd)/Resources/Sprites"
try? FileManager.default.createDirectory(atPath: outputDir, withIntermediateDirectories: true)

print("Generating terrain sprites...")
grassSprite().savePNG(to: "\(outputDir)/terrain-grass.png")
forestSprite().savePNG(to: "\(outputDir)/terrain-forest.png")
beachSprite().savePNG(to: "\(outputDir)/terrain-beach.png")
waterSprite().savePNG(to: "\(outputDir)/terrain-water.png")
mountainSprite().savePNG(to: "\(outputDir)/terrain-mountain.png")

print("Generating building sprites...")
houseSprite().savePNG(to: "\(outputDir)/building-house.png")
warehouseSprite().savePNG(to: "\(outputDir)/building-warehouse.png")
lumberjackHutSprite().savePNG(to: "\(outputDir)/building-lumberjack_hut.png")
sawmillSprite().savePNG(to: "\(outputDir)/building-sawmill.png")
townCenterSprite().savePNG(to: "\(outputDir)/building-town_center.png")
roadSprite().savePNG(to: "\(outputDir)/building-road.png")

print("Done. Sprites in \(outputDir)/")
