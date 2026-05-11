#!/usr/bin/env swift
// scripts/generate-sprites.swift
//
// Procedurally generates "olden days" isometric pixel-art sprites for the
// MVP renderer. Inspired by Caesar III / Anno 1602 / SimCity 2000 — small
// palette, blocky pixels, strong outlines, simple cell-shaded surfaces.
//
// Output (run from repo root):
//   Resources/Terrain.atlas/terrain-<kind>.png         (64x32 each, static)
//   Resources/Terrain.atlas/terrain-<kind>-<frame>.png (water/beach/grass)
//   Resources/Buildings.atlas/building-<kind>.png      (static)
//   Resources/Buildings.atlas/building-<kind>-operational-<frame>.png
//                                                   (sawmill/lumberjack_hut/
//                                                    town_center idle anim)
//   Resources/Buildings.atlas/building-<kind>-constructing-<frame>.png
//                                                   (3-stage scaffold rise,
//                                                    every building kind)
//   Resources/Units.atlas/walker-<facing>-<frame>.png  (2-frame walk × 4 facings)
//
// Routing rule: PNGs are routed into a `<Category>.atlas/` subfolder by
// filename prefix:
//   `terrain-`  → Terrain.atlas
//   `building-` → Buildings.atlas
//   `walker-`   → Units.atlas
//
// Frame naming follows the SpriteAnimation catalog in CityRender2D:
//   SpriteAnimation.assetName(for:frame:) MUST match these paths.
//
// Frame helpers:
//   drawWaterShimmer    cycles foam ripples horizontally for 4-frame water
//   drawSmokeOffset     shifts and fades chimney puffs per frame
//   drawSawBlade(...angleStep:) rotates the spinning saw spoke marks
//   drawFlagWave        offsets the flag's trailing edge per frame
//   drawScaffold        overlays rising scaffold poles + tarpaulin
//
// Run via:
//   swift scripts/generate-sprites.swift                # writes to Resources/
//   swift scripts/generate-sprites.swift <outputRoot>   # writes to <outputRoot>/

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
    grassFrame(frame: 0)
}

/// Two-frame gentle grass shimmer. Frame 0 matches the original static
/// grass sprite (dark tufts at step 13, light highlights at step 19).
/// Frame 1 inverts which stipple is dense vs. sparse so a handful of
/// pixels swap dark↔light — a barely-there "breath" at 0.6 s/frame
/// suggesting wind without making the ground feel busy.
func grassFrame(frame: Int) -> Pixmap {
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
    let darkStep = (frame == 0) ? 13 : 19
    let lightStep = (frame == 0) ? 19 : 13
    stippleDiamond(
        p,
        originX: 0,
        originY: 0,
        width: 64,
        height: 32,
        color: P.grassDark,
        step: darkStep
    )
    stippleDiamond(
        p,
        originX: 0,
        originY: 0,
        width: 64,
        height: 32,
        color: P.grassLight,
        step: lightStep
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
    beachFrame(frame: 0)
}

/// Two-frame beach cycle. Frame 0 matches the original static beach
/// sprite. Frame 1 adds a single foam wash line near the upper-left
/// edge so the shoreline appears to breathe.
func beachFrame(frame: Int) -> Pixmap {
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
    stippleDiamond(
        p,
        originX: 0,
        originY: 0,
        width: 64,
        height: 32,
        color: P.beachDark,
        step: 17
    )
    if frame == 1 {
        // Wave wash near the back edge of the diamond — a short curve of
        // light pixels suggesting a tide line.
        let foam: [(Int, Int)] = [
            (18, 8), (22, 7), (26, 7), (30, 6), (34, 7), (38, 7), (42, 8)
        ]
        for (x, y) in foam { p.set(x, y, P.waterFoam) }
    }
    return p
}

func waterSprite() -> Pixmap {
    waterFrame(frame: 0)
}

/// One frame of the water shimmer cycle. Frame 0 matches the original
/// static water sprite so existing references stay visually consistent.
/// Frames 1-3 cycle the foam ripple positions horizontally and shift the
/// wave-line crests vertically by one pixel.
func waterFrame(frame: Int) -> Pixmap {
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
    let xShift = frame * 2 // 0, 2, 4, 6 — wraps via stride bounds checks
    let yShift = (frame % 2 == 0) ? 0 : 1
    // Upper ripple: pairs of lighter pixels in a wavy line.
    let upperBaseX = 20 + xShift
    for i in 0 ... 6 {
        let x = upperBaseX + i * 4
        let y = 12 + (i % 2 == 0 ? 0 : 1) + yShift
        if x < 60 { p.set(x, y, P.waterFoam) }
    }
    // Lower ripple (out of phase with upper).
    let lowerBaseX = 26 + ((frame + 2) * 2 % 8)
    for i in 0 ... 3 {
        let x = lowerBaseX + i * 4
        let y = 20 + (i % 2 == 0 ? 0 : 1) - yShift
        if x < 56, y >= 0 { p.set(x, y, P.waterFoam) }
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
    // Two-faced rocky peak: left (sun-lit) is `mountainLight`, right
    // (shaded) is `mountain`, with a single-pixel `mountainDark` outline
    // along the silhouette. The snow cap sits on top with a wavy lower
    // edge (so it doesn't read as a hat brim). Scattered crag pixels on
    // the shaded face give the surface some texture without resorting
    // to the column-parity stripes the previous version had.
    let peakCenter = 32
    let peakRows = 14
    let topY = 4
    // Wavy snow edge — for each column offset (dx), the snow extends
    // down this many rows from `topY`. Hand-tuned for a "rocky cap".
    let snowDepthByDx: [Int: Int] = [
        -6: 2, -5: 3, -4: 4, -3: 5, -2: 6, -1: 5,
        0: 6, 1: 5, 2: 5, 3: 4, 4: 4, 5: 3, 6: 2
    ]
    for row in 0 ..< peakRows {
        let halfW = max(2, 7 - row / 3)
        let yy = topY + row
        for dx in -halfW ... halfW {
            let isLeftFace = dx < 0
            let isRim = (dx == -halfW || dx == halfW)
            let snowHere = row < (snowDepthByDx[dx] ?? 0)
            let color: Color
            if snowHere {
                color = (isRim && row > 1) ? P.mountainDark : P.snow
            } else if isRim {
                color = P.mountainDark
            } else if isLeftFace {
                color = P.mountainLight
            } else {
                color = P.mountain
            }
            p.set(peakCenter + dx, yy, color)
        }
    }
    // A handful of crag-detail pixels on the shaded face for texture.
    let crags: [(Int, Int)] = [
        (peakCenter + 2, topY + 8),
        (peakCenter + 4, topY + 10),
        (peakCenter + 1, topY + 11),
        (peakCenter + 3, topY + 12)
    ]
    for (cx, cy) in crags { p.set(cx, cy, P.mountainDark) }
    // Anchor the peak into the diamond with a darker scree skirt at the
    // base so the mountain doesn't appear to float.
    for dx in -8 ... 8 {
        let yy = topY + peakRows
        p.set(peakCenter + dx, yy, P.mountainDark)
    }
    return p
}

// MARK: - Building sprites

// MARK: - Building drawing helpers

/// Draw the wall body of a building. Returns the body rectangle so the
/// caller can decorate it with windows, doors, etc.
struct BodyRect { let x: Int; let y: Int; let w: Int; let h: Int }

func drawBody(
    _ p: Pixmap,
    rect: BodyRect,
    wallLeft: Color, wallRight: Color, wallTopShadow: Color
) {
    // Left face (lighter, sun-facing).
    p.fillRect(x: rect.x, y: rect.y, w: rect.w / 2, h: rect.h, wallLeft)
    // Right face (shadow side).
    p.fillRect(x: rect.x + rect.w / 2, y: rect.y, w: rect.w / 2, h: rect.h, wallRight)
    // Outline the body.
    for dy in 0 ..< rect.h {
        p.set(rect.x, rect.y + dy, P.outline)
        p.set(rect.x + rect.w - 1, rect.y + dy, P.outline)
    }
    for dx in 0 ..< rect.w { p.set(rect.x + dx, rect.y, P.outline) }
    // Top-edge shadow (eaves overhang).
    for dx in 1 ..< rect.w - 1 { p.set(rect.x + dx, rect.y + 1, wallTopShadow) }
    // Vertical corner seam where the two faces meet.
    let seamX = rect.x + rect.w / 2
    for dy in 0 ..< rect.h {
        p.set(seamX, rect.y + dy, P.outline)
    }
}

func drawWindow(_ p: Pixmap, x: Int, y: Int, w: Int = 4, h: Int = 4) {
    // Frame
    p.fillRect(x: x - 1, y: y - 1, w: w + 2, h: h + 2, P.outline)
    // Glow
    p.fillRect(x: x, y: y, w: w, h: h, P.windowYellow)
    // Cross-bar (mullion)
    if w >= 3 {
        for dy in 0 ..< h { p.set(x + w / 2, y + dy, P.outline) }
    }
    if h >= 3 {
        for dx in 0 ..< w { p.set(x + dx, y + h / 2, P.outline) }
    }
}

func drawDoor(_ p: Pixmap, x: Int, y: Int, w: Int, h: Int, frame: Color, panel: Color) {
    // Door panel
    p.fillRect(x: x, y: y, w: w, h: h, panel)
    // Frame
    for dy in 0 ..< h {
        p.set(x, y + dy, frame)
        p.set(x + w - 1, y + dy, frame)
    }
    for dx in 0 ..< w {
        p.set(x + dx, y, frame)
    }
    // Tiny doorknob
    p.set(x + w - 2, y + h / 2, P.roofGold)
}

/// Draw a pitched roof with shingle texture and ridge highlight.
func drawPitchedRoof(
    _ p: Pixmap,
    bodyX: Int, bodyY: Int, bodyW: Int,
    height: Int,
    overhang: Int = 2,
    fill: Color, dark: Color, highlight: Color
) {
    let roofBottom = bodyY - 1
    let roofTop = bodyY - height
    let leftBase = bodyX - overhang
    let rightBase = bodyX + bodyW - 1 + overhang
    for r in 0 ... height {
        let progress = Double(r) / Double(max(1, height))
        let inset = Int(progress * Double((rightBase - leftBase) / 2))
        let left = leftBase + inset
        let right = rightBase - inset
        let y = roofBottom - r
        guard y >= 0, left <= right else { continue }
        for x in left ... right {
            // Two-tone: left half lighter, right half base color, ridge in dark.
            let halfX = (left + right) / 2
            let isLeft = x <= halfX
            var color = isLeft ? fill : dark
            // Shingle row every 2 px gets a darker stripe.
            if r % 2 == 1 { color = isLeft ? color.darker(15) : color.darker(15) }
            // Ridge highlight on the very top row.
            if r == height { color = highlight }
            p.set(x, y, color)
        }
        // Roof outline pixels.
        p.set(left, y, P.outline)
        p.set(right, y, P.outline)
    }
    // Eaves shadow — 1-pixel dark line right under the overhang.
    let eaveY = bodyY
    for x in leftBase ... rightBase {
        p.set(x, eaveY, P.outline)
    }
}

func drawChimney(_ p: Pixmap, x: Int, y: Int, w: Int = 4, h: Int = 6) {
    p.fillRect(x: x, y: y, w: w, h: h, P.stoneWallDark)
    for dy in 0 ..< h { p.set(x, y + dy, P.outline); p.set(x + w - 1, y + dy, P.outline) }
    p.fillRect(x: x, y: y, w: w, h: 1, P.stoneWall)
}

func drawSmoke(_ p: Pixmap, atX cx: Int, atY cy: Int) {
    drawSmoke(p, atX: cx, atY: cy, frame: 0)
}

/// Frame-aware smoke. Each puff rises by 1px and fades slightly per
/// frame; the bottom puff is replaced by a smaller fresh puff so the
/// stream looks continuous rather than ascending out of existence.
func drawSmoke(_ p: Pixmap, atX cx: Int, atY cy: Int, frame: Int) {
    let lift = frame
    let puffs: [(Int, Int, Int)] = [
        (cx, cy - lift, 2),
        (cx - 2, cy - 3 - lift, 2),
        (cx + 1, cy - 5 - lift, 3),
        (cx - 1, cy - 8 - lift, max(1, 2 - frame / 2))
    ]
    for (px, py, r) in puffs {
        for dy in -r ... r {
            for dx in -r ... r where dx * dx + dy * dy <= r * r {
                let base = (dx + dy) % 2 == 0
                    ? Color(220, 220, 220, 200)
                    : Color(190, 190, 190, 180)
                p.set(px + dx, py + dy, base)
            }
        }
    }
    // Fresh small puff at the chimney mouth so the stream regenerates.
    if frame > 0 {
        p.set(cx, cy + 1, Color(230, 230, 230, 210))
        p.set(cx + 1, cy + 1, Color(220, 220, 220, 200))
    }
}

func drawLogPile(_ p: Pixmap, atX baseX: Int, atY baseY: Int) {
    // Three logs stacked: two on bottom, one on top.
    for (offsetX, offsetY) in [(0, 0), (10, 0), (5, -4)] {
        let lx = baseX + offsetX
        let ly = baseY + offsetY
        // Side (the long rectangle)
        p.fillRect(x: lx, y: ly, w: 10, h: 4, P.woodWall)
        // Outline
        for dx in 0 ..< 10 {
            p.set(lx + dx, ly, P.woodWallDark)
            p.set(lx + dx, ly + 3, P.outline)
        }
        // End-grain disc
        p.fillRect(x: lx, y: ly, w: 2, h: 4, P.woodWallLight)
        p.set(lx, ly + 1, P.woodWallDark)
        p.set(lx + 1, ly + 2, P.woodWallDark)
        p.set(lx + 10, ly + 1, P.outline)
        p.set(lx + 10, ly + 2, P.outline)
    }
}

func drawPlankStack(_ p: Pixmap, atX baseX: Int, atY baseY: Int) {
    // Stack of horizontal planks.
    for row in 0 ..< 4 {
        let yy = baseY - row * 2
        p.fillRect(x: baseX, y: yy, w: 14, h: 2, P.beach)
        for dx in 0 ..< 14 {
            p.set(baseX + dx, yy + 1, P.beachDark)
        }
        p.set(baseX, yy, P.outline)
        p.set(baseX + 13, yy, P.outline)
    }
}

func drawSawBlade(_ p: Pixmap, atX cx: Int, atY cy: Int, radius r: Int = 6) {
    drawSawBlade(p, atX: cx, atY: cy, radius: r, frame: 0)
}

/// Frame-aware blade. The spoke marks rotate around the hub per frame
/// so the blade reads as spinning. `frame` cycles through 4 spoke
/// orientations (0, 30°, 60°, 90° — close enough to suggest rotation
/// without sub-pixel math).
func drawSawBlade(_ p: Pixmap, atX cx: Int, atY cy: Int, radius r: Int = 6, frame: Int) {
    for dy in -r ... r {
        for dx in -r ... r {
            let distSq = dx * dx + dy * dy
            if distSq <= r * r {
                let color: Color
                if distSq >= (r - 1) * (r - 1) {
                    color = (dx + dy) % 2 == 0 ? P.outline : Color(210, 210, 220)
                } else if distSq <= 2 {
                    color = P.outline
                } else {
                    color = Color(180, 180, 200)
                }
                p.set(cx + dx, cy + dy, color)
            }
        }
    }
    // Four spoke positions cycle per frame. Each puts 4 spoke pixels
    // at a different angle, suggesting rotation.
    let spokeOffsets: [[(Int, Int)]] = [
        [(0, -r + 2), (r - 2, 0), (0, r - 2), (-r + 2, 0)],
        [(2, -r + 3), (r - 3, 2), (-2, r - 3), (-r + 3, -2)],
        [(r - 3, -2), (2, r - 3), (-r + 3, 2), (-2, -r + 3)],
        [(r - 2, 0), (0, r - 2), (-r + 2, 0), (0, -r + 2)]
    ]
    for (dx, dy) in spokeOffsets[frame % spokeOffsets.count] {
        p.set(cx + dx, cy + dy, P.outline)
    }
}

func drawFlag(_ p: Pixmap, poleX: Int, poleTopY: Int, poleHeight: Int) {
    drawFlag(p, poleX: poleX, poleTopY: poleTopY, poleHeight: poleHeight, frame: 0)
}

/// Frame-aware flag. Two frames trade the trailing edge's curl: frame 0
/// trails high (taut), frame 1 trails lower (sagging gust).
func drawFlag(_ p: Pixmap, poleX: Int, poleTopY: Int, poleHeight: Int, frame: Int) {
    for dy in 0 ..< poleHeight {
        p.set(poleX, poleTopY + dy, P.outline)
    }
    let taut: [(Int, Int)] = [
        (poleX + 1, poleTopY + 1), (poleX + 2, poleTopY + 1), (poleX + 3, poleTopY + 1),
        (poleX + 4, poleTopY + 1), (poleX + 5, poleTopY + 1), (poleX + 6, poleTopY + 1),
        (poleX + 1, poleTopY + 2), (poleX + 2, poleTopY + 2), (poleX + 3, poleTopY + 2),
        (poleX + 4, poleTopY + 2), (poleX + 5, poleTopY + 2),
        (poleX + 1, poleTopY + 3), (poleX + 2, poleTopY + 3), (poleX + 3, poleTopY + 3),
        (poleX + 4, poleTopY + 3),
        (poleX + 1, poleTopY + 4), (poleX + 2, poleTopY + 4), (poleX + 3, poleTopY + 4)
    ]
    let sag: [(Int, Int)] = [
        (poleX + 1, poleTopY + 1), (poleX + 2, poleTopY + 1), (poleX + 3, poleTopY + 1),
        (poleX + 4, poleTopY + 1), (poleX + 5, poleTopY + 1),
        (poleX + 1, poleTopY + 2), (poleX + 2, poleTopY + 2), (poleX + 3, poleTopY + 2),
        (poleX + 4, poleTopY + 2), (poleX + 5, poleTopY + 2), (poleX + 6, poleTopY + 2),
        (poleX + 1, poleTopY + 3), (poleX + 2, poleTopY + 3), (poleX + 3, poleTopY + 3),
        (poleX + 4, poleTopY + 3), (poleX + 5, poleTopY + 3),
        (poleX + 1, poleTopY + 4), (poleX + 2, poleTopY + 4),
        (poleX + 1, poleTopY + 5)
    ]
    let pixels = (frame == 0) ? taut : sag
    for (fx, fy) in pixels { p.set(fx, fy, P.roofRed) }
    if frame == 0 {
        p.set(poleX + 6, poleTopY + 2, P.outline)
        p.set(poleX + 5, poleTopY + 3, P.outline)
        p.set(poleX + 4, poleTopY + 4, P.outline)
    } else {
        p.set(poleX + 7, poleTopY + 2, P.outline)
        p.set(poleX + 6, poleTopY + 3, P.outline)
        p.set(poleX + 3, poleTopY + 4, P.outline)
        p.set(poleX + 2, poleTopY + 5, P.outline)
    }
}

/// Overlay a wooden scaffold cage on top of the building's body. `stage`
/// 0..totalStages-1 controls how high the scaffold rises and how much
/// of the underlying building shows through (tarpaulin cover).
///
/// Stage 0: foundation only, scaffold base just above tile.
/// Stage 1: scaffold reaches mid-body height, lower walls visible.
/// Stage 2: scaffold reaches full body height, near-complete.
func drawScaffold(
    _ p: Pixmap,
    bodyX: Int, bodyY: Int, bodyW: Int, bodyH: Int,
    stage: Int, totalStages: Int
) {
    let stages = max(1, totalStages)
    let clamped = max(0, min(stage, stages - 1))
    let progress = Double(clamped + 1) / Double(stages)
    let scaffoldH = Int(progress * Double(bodyH))
    let scaffoldTopY = bodyY + bodyH - scaffoldH

    // Tarpaulin: light beige rectangle covering the upper portion of
    // the building, hiding the not-yet-finished walls. Stage advances
    // shrink it from the top so the building "reveals" itself.
    let coverTop = bodyY
    let coverBottom = scaffoldTopY
    if coverBottom > coverTop {
        p.fillRect(
            x: bodyX, y: coverTop,
            w: bodyW, h: coverBottom - coverTop,
            Color(200, 184, 144)
        )
        // Tarpaulin shading: a few horizontal lines.
        for row in stride(from: coverTop + 2, to: coverBottom, by: 3) {
            for x in (bodyX + 1) ..< (bodyX + bodyW - 1) {
                p.set(x, row, Color(168, 152, 116))
            }
        }
        // Outline
        for dy in coverTop ..< coverBottom {
            p.set(bodyX, dy, P.outline)
            p.set(bodyX + bodyW - 1, dy, P.outline)
        }
        for dx in bodyX ..< (bodyX + bodyW) {
            p.set(dx, coverTop, P.outline)
        }
    }

    // Scaffold poles: four vertical posts in front, one cross-brace.
    let postCols = [bodyX + 2, bodyX + bodyW / 3, bodyX + 2 * bodyW / 3, bodyX + bodyW - 3]
    let postBottom = bodyY + bodyH + 1
    let postTop = scaffoldTopY - 2
    for col in postCols where col > bodyX && col < bodyX + bodyW {
        let yStart = max(0, postTop)
        if postBottom >= yStart {
            for y in yStart ... postBottom {
                p.set(col, y, P.woodWallDark)
            }
        }
    }
    // Horizontal walking plank at the top of the current scaffold.
    if postTop >= 0 {
        for x in (bodyX + 1) ..< (bodyX + bodyW - 1) {
            p.set(x, postTop, P.woodWall)
            p.set(x, postTop + 1, P.woodWallDark)
        }
    }
    // Diagonal cross-brace on the lower section for visual texture.
    let braceY0 = postBottom - 4
    let braceY1 = postBottom
    let braceX0 = bodyX + 2
    let braceX1 = bodyX + bodyW / 3
    let steps = max(1, braceX1 - braceX0)
    for i in 0 ... steps {
        let x = braceX0 + i
        let y = braceY0 + (braceY1 - braceY0) * i / steps
        p.set(x, y, P.woodWallDark)
    }
}

func setupBuildingCanvas(footprintW: Int, footprintH: Int, totalHeight: Int) -> (canvas: Pixmap, baseY: Int) {
    let tileW = footprintW * 64
    let tileH = footprintH * 32
    let p = Pixmap(width: tileW, height: totalHeight)
    let baseY = totalHeight - tileH
    // Foundation diamond (the building's footprint as a darker stone tile).
    drawIsoDiamond(
        p, originX: 0, originY: baseY, width: tileW, height: tileH,
        fill: P.stoneWallDark, edge: P.outline, highlight: nil
    )
    return (p, baseY)
}

// MARK: - Per-building hand-drawn sprites

func houseSprite() -> Pixmap { houseSprite(frame: 0) }

func houseSprite(frame: Int) -> Pixmap {
    // 2x2 footprint, modest cottage with chimney + smoke.
    // Body bottom sits AT the diamond midline so the building visually
    // embeds into the tile; only the front V of the foundation shows.
    let footprintH = 2
    let tileH = footprintH * 32
    let totalH = 32 + 32 + 32 + tileH / 2 // chimney + roof + body + diamond-bottom-half
    let (p, baseY) = setupBuildingCanvas(footprintW: 2, footprintH: footprintH, totalHeight: totalH)
    let bodyH = 30
    let bodyW = 56
    let bodyX = (p.width - bodyW) / 2
    let bodyBottom = baseY + tileH / 2 // diamond midline
    let bodyY = bodyBottom - bodyH
    drawBody(p, rect: BodyRect(x: bodyX, y: bodyY, w: bodyW, h: bodyH),
             wallLeft: P.woodWallLight, wallRight: P.woodWall,
             wallTopShadow: P.woodWallDark)
    // Vertical wood beams every 8px on both faces.
    for x in stride(from: bodyX + 8, to: bodyX + bodyW - 4, by: 8) {
        for dy in 1 ..< bodyH { p.set(x, bodyY + dy, P.woodWallDark) }
    }
    // Windows: two on each visible face.
    drawWindow(p, x: bodyX + 6, y: bodyY + 6, w: 5, h: 5)
    drawWindow(p, x: bodyX + 18, y: bodyY + 6, w: 5, h: 5)
    drawWindow(p, x: bodyX + 32, y: bodyY + 6, w: 5, h: 5)
    drawWindow(p, x: bodyX + 44, y: bodyY + 6, w: 5, h: 5)
    // Door at center-front-left
    drawDoor(p, x: bodyX + bodyW / 2 - 6, y: bodyY + bodyH - 12,
             w: 5, h: 11, frame: P.outline, panel: P.woodWallDark)
    // Roof
    drawPitchedRoof(p, bodyX: bodyX, bodyY: bodyY, bodyW: bodyW, height: 16,
                    overhang: 3, fill: P.roofRed, dark: P.roofRedDark, highlight: Color(220, 100, 80))
    // Chimney + smoke (frame-aware for house too — even idle houses
    // have a chimney that could puff, but for now only the static
    // sprite is published so frame defaults to 0).
    drawChimney(p, x: bodyX + bodyW - 18, y: bodyY - 22)
    drawSmoke(p, atX: bodyX + bodyW - 16, atY: bodyY - 26, frame: frame)
    return p
}

func warehouseSprite() -> Pixmap {
    // 3x3 footprint, stone warehouse with stacked crates.
    let footprintH = 3
    let tileH = footprintH * 32
    let totalH = 24 + 24 + 44 + tileH / 2 + 8
    let (p, baseY) = setupBuildingCanvas(footprintW: 3, footprintH: footprintH, totalHeight: totalH)
    let bodyH = 44
    let bodyW = 96
    let bodyX = (p.width - bodyW) / 2
    let bodyBottom = baseY + tileH / 2
    let bodyY = bodyBottom - bodyH
    drawBody(p, rect: BodyRect(x: bodyX, y: bodyY, w: bodyW, h: bodyH),
             wallLeft: P.stoneWallLight, wallRight: P.stoneWall,
             wallTopShadow: P.stoneWallDark)
    // Brick pattern: alternating row offsets.
    for row in stride(from: 4, to: bodyH - 4, by: 4) {
        let offset = (row / 4) % 2 == 0 ? 0 : 4
        for x in stride(from: bodyX + 2 + offset, to: bodyX + bodyW - 2, by: 8) {
            p.set(x, bodyY + row, P.stoneWallDark)
            p.set(x + 1, bodyY + row, P.stoneWallDark)
        }
    }
    // Row of windows along the top of each face
    for x in stride(from: bodyX + 6, to: bodyX + bodyW - 8, by: 12) {
        drawWindow(p, x: x, y: bodyY + 5, w: 6, h: 5)
    }
    // Big double doors at the front-center
    let doorW = 16
    let doorX = bodyX + bodyW / 2 - doorW / 2
    let doorY = bodyY + bodyH - 18
    drawDoor(p, x: doorX, y: doorY, w: doorW, h: 17,
             frame: P.outline, panel: P.woodWallDark)
    // Door split line down the middle
    for dy in 0 ..< 17 { p.set(doorX + doorW / 2, doorY + dy, P.outline) }
    // Hipped roof (lower profile than pitched)
    drawPitchedRoof(p, bodyX: bodyX, bodyY: bodyY, bodyW: bodyW, height: 20,
                    overhang: 4, fill: P.roofGrey, dark: P.roofGreyDark,
                    highlight: Color(140, 140, 150))
    // Crates beside the building, at the front-of-tile (lower diamond
    // half) so they don't disappear behind the wall.
    let crateY = baseY + tileH - 16
    let crateX = bodyX - 14
    for (cx, cy) in [(crateX, crateY), (crateX + 10, crateY), (crateX + 5, crateY - 8)] {
        p.fillRect(x: cx, y: cy, w: 10, h: 8, P.woodWall)
        for dy in 0 ..< 8 {
            p.set(cx, cy + dy, P.outline)
            p.set(cx + 9, cy + dy, P.outline)
        }
        for dx in 0 ..< 10 {
            p.set(cx + dx, cy, P.outline)
            p.set(cx + dx, cy + 7, P.outline)
        }
        p.set(cx + 4, cy + 4, P.woodWallDark)
        p.set(cx + 5, cy + 4, P.woodWallDark)
    }
    return p
}

func lumberjackHutSprite() -> Pixmap { lumberjackHutSprite(frame: 0) }

func lumberjackHutSprite(frame: Int) -> Pixmap {
    // 2x2 footprint: rough log cabin with stacked logs and a chopping block.
    let footprintH = 2
    let tileH = footprintH * 32
    let totalH = 16 + 16 + 26 + tileH / 2 + 4
    let (p, baseY) = setupBuildingCanvas(footprintW: 2, footprintH: footprintH, totalHeight: totalH)
    let bodyH = 26
    let bodyW = 52
    let bodyX = (p.width - bodyW) / 2
    let bodyBottom = baseY + tileH / 2
    let bodyY = bodyBottom - bodyH
    drawBody(p, rect: BodyRect(x: bodyX, y: bodyY, w: bodyW, h: bodyH),
             wallLeft: P.woodWall, wallRight: P.woodWallDark,
             wallTopShadow: Color(60, 40, 22))
    // Horizontal log-pattern lines on the walls (log cabin style).
    for row in stride(from: 3, to: bodyH - 2, by: 4) {
        for dx in 1 ..< bodyW - 1 { p.set(bodyX + dx, bodyY + row, Color(72, 50, 24)) }
    }
    // Small window
    drawWindow(p, x: bodyX + 8, y: bodyY + 4, w: 4, h: 4)
    drawWindow(p, x: bodyX + bodyW - 12, y: bodyY + 4, w: 4, h: 4)
    // Door
    drawDoor(p, x: bodyX + bodyW / 2 - 3, y: bodyY + bodyH - 10,
             w: 5, h: 9, frame: P.outline, panel: Color(60, 40, 22))
    // Forest-green shingle roof
    drawPitchedRoof(p, bodyX: bodyX, bodyY: bodyY, bodyW: bodyW, height: 14,
                    overhang: 3, fill: P.forest, dark: P.forestDark, highlight: P.forestLight)
    // Small stone chimney at the back of the roof + frame-aware smoke.
    drawChimney(p, x: bodyX + bodyW - 14, y: bodyY - 10, w: 3, h: 6)
    drawSmoke(p, atX: bodyX + bodyW - 13, atY: bodyY - 14, frame: frame)
    // Log pile to the right of the hut, in the front of the tile.
    drawLogPile(p, atX: bodyX + bodyW + 2, atY: baseY + tileH - 14)
    // Chopping block with axe to the left, front of tile.
    let stumpX = bodyX - 12
    let stumpY = baseY + tileH - 12
    p.fillRect(x: stumpX, y: stumpY, w: 8, h: 6, P.woodWall)
    for dx in 0 ..< 8 { p.set(stumpX + dx, stumpY, P.woodWallDark) }
    for dx in 0 ..< 8 { p.set(stumpX + dx, stumpY + 5, P.outline) }
    p.set(stumpX, stumpY + 2, P.outline)
    p.set(stumpX + 7, stumpY + 2, P.outline)
    // Axe stuck in stump
    p.set(stumpX + 4, stumpY - 1, P.outline)
    p.set(stumpX + 4, stumpY - 2, P.outline)
    p.set(stumpX + 4, stumpY - 3, P.woodWallDark)
    p.set(stumpX + 4, stumpY - 4, P.woodWallDark)
    p.fillRect(x: stumpX + 3, y: stumpY - 6, w: 3, h: 2, Color(180, 180, 190))
    return p
}

func sawmillSprite() -> Pixmap { sawmillSprite(frame: 0) }

func sawmillSprite(frame: Int) -> Pixmap {
    // 2x2: stone foundation, half-timbered walls, big circular saw + plank stacks.
    let footprintH = 2
    let tileH = footprintH * 32
    let totalH = 18 + 20 + 30 + tileH / 2 + 6
    let (p, baseY) = setupBuildingCanvas(footprintW: 2, footprintH: footprintH, totalHeight: totalH)
    let bodyH = 30
    let bodyW = 56
    let bodyX = (p.width - bodyW) / 2
    let bodyBottom = baseY + tileH / 2
    let bodyY = bodyBottom - bodyH
    drawBody(p, rect: BodyRect(x: bodyX, y: bodyY, w: bodyW, h: bodyH),
             wallLeft: P.stoneWallLight, wallRight: P.stoneWall,
             wallTopShadow: P.stoneWallDark)
    // Half-timber pattern: dark wood Xs on the upper half of each face.
    for x in stride(from: bodyX + 2, to: bodyX + bodyW - 6, by: 12) {
        // Diagonal beams forming an X
        for offset in 0 ..< 8 {
            p.set(x + offset, bodyY + 2 + offset, P.woodWallDark)
            p.set(x + 7 - offset, bodyY + 2 + offset, P.woodWallDark)
        }
    }
    // Windows on lower half
    drawWindow(p, x: bodyX + 6, y: bodyY + 13, w: 5, h: 5)
    drawWindow(p, x: bodyX + bodyW - 12, y: bodyY + 13, w: 5, h: 5)
    // Front door
    drawDoor(p, x: bodyX + bodyW / 2 - 4, y: bodyY + bodyH - 12,
             w: 6, h: 11, frame: P.outline, panel: P.woodWallDark)
    // Wood-shingle roof
    drawPitchedRoof(p, bodyX: bodyX, bodyY: bodyY, bodyW: bodyW, height: 16,
                    overhang: 3, fill: P.woodWallDark, dark: Color(60, 40, 22),
                    highlight: P.woodWall)
    // Big saw blade on the side of the building (next to the wall).
    drawSawBlade(p, atX: bodyX + bodyW + 8, atY: bodyBottom - 10, radius: 8, frame: frame)
    // Plank stack at the front of the tile.
    drawPlankStack(p, atX: bodyX - 16, atY: baseY + tileH - 6)
    // Chimney with smoke
    drawChimney(p, x: bodyX + 6, y: bodyY - 16, w: 4, h: 8)
    drawSmoke(p, atX: bodyX + 8, atY: bodyY - 20, frame: frame)
    return p
}

func townCenterSprite() -> Pixmap { townCenterSprite(frame: 0) }

func townCenterSprite(frame: Int) -> Pixmap {
    // 3x3: grand civic building with a bell tower and flag.
    let footprintH = 3
    let tileH = footprintH * 32
    let totalH = 24 + 22 + 14 + 56 + tileH / 2 // flag + tower roof + tower + body + diamond-bottom-half
    let (p, baseY) = setupBuildingCanvas(footprintW: 3, footprintH: footprintH, totalHeight: totalH)
    let bodyH = 56
    let bodyW = 104
    let bodyX = (p.width - bodyW) / 2
    let bodyBottom = baseY + tileH / 2
    let bodyY = bodyBottom - bodyH
    drawBody(p, rect: BodyRect(x: bodyX, y: bodyY, w: bodyW, h: bodyH),
             wallLeft: Color(220, 212, 188), wallRight: P.stoneWallLight,
             wallTopShadow: P.stoneWall)
    // Pilaster columns (5 across the front).
    for x in stride(from: bodyX + 8, to: bodyX + bodyW - 6, by: 18) {
        for dy in 0 ..< bodyH {
            p.set(x, bodyY + dy, P.stoneWallDark)
            p.set(x + 1, bodyY + dy, P.stoneWall)
        }
    }
    // Tall arched windows between pilasters.
    for x in stride(from: bodyX + 12, to: bodyX + bodyW - 10, by: 18) {
        // Rectangular pane
        p.fillRect(x: x, y: bodyY + 12, w: 6, h: 18, P.windowYellow)
        // Outline
        for dy in 0 ..< 18 {
            p.set(x - 1, bodyY + 12 + dy, P.outline)
            p.set(x + 6, bodyY + 12 + dy, P.outline)
        }
        for dx in 0 ..< 6 { p.set(x + dx, bodyY + 30, P.outline) }
        // Arched top
        for ax in 0 ..< 6 {
            let dist = abs(ax - 3)
            let yy = bodyY + 8 + dist
            p.set(x + ax, yy, P.windowYellow)
            p.set(x + ax, yy - 1, P.outline)
        }
        // Mullion
        for dy in 0 ..< 18 { p.set(x + 3, bodyY + 12 + dy, P.outline) }
    }
    // Grand double doors at center
    let doorW = 18
    let doorX = bodyX + bodyW / 2 - doorW / 2
    let doorY = bodyY + bodyH - 22
    drawDoor(p, x: doorX, y: doorY, w: doorW, h: 21,
             frame: P.outline, panel: P.woodWall)
    // Door panels with crossbeams
    for dy in 0 ..< 21 { p.set(doorX + doorW / 2, doorY + dy, P.outline) }
    p.fillRect(x: doorX + 2, y: doorY + 7, w: doorW - 4, h: 1, P.woodWallDark)
    p.fillRect(x: doorX + 2, y: doorY + 14, w: doorW - 4, h: 1, P.woodWallDark)
    // Main hipped roof
    drawPitchedRoof(p, bodyX: bodyX, bodyY: bodyY, bodyW: bodyW, height: 18,
                    overhang: 4, fill: P.roofGold, dark: P.roofGoldDark,
                    highlight: Color(255, 220, 120))
    // Bell tower rising above the roof
    let towerW = 18
    let towerH = 26
    let towerX = bodyX + bodyW / 2 - towerW / 2
    let towerY = bodyY - 18 - towerH
    p.fillRect(x: towerX, y: towerY, w: towerW, h: towerH, P.stoneWallLight)
    for dy in 0 ..< towerH {
        p.set(towerX, towerY + dy, P.outline)
        p.set(towerX + towerW - 1, towerY + dy, P.outline)
    }
    for dx in 0 ..< towerW {
        p.set(towerX + dx, towerY, P.outline)
        p.set(towerX + dx, towerY + towerH - 1, P.outline)
    }
    // Tower window (arched)
    p.fillRect(x: towerX + 5, y: towerY + 8, w: 8, h: 10, P.outline)
    p.fillRect(x: towerX + 6, y: towerY + 9, w: 6, h: 8, P.windowYellow)
    for ax in 0 ..< 6 {
        let dist = abs(ax - 2)
        p.set(towerX + 6 + ax, towerY + 6 + dist, P.windowYellow)
        p.set(towerX + 6 + ax, towerY + 5 + dist, P.outline)
    }
    // Bell visible in window
    p.fillRect(x: towerX + 8, y: towerY + 11, w: 3, h: 4, P.roofGold)
    p.set(towerX + 8, towerY + 11, P.outline)
    p.set(towerX + 10, towerY + 11, P.outline)
    // Pyramid roof on tower
    drawPitchedRoof(p, bodyX: towerX, bodyY: towerY, bodyW: towerW, height: 12,
                    overhang: 2, fill: P.roofRed, dark: P.roofRedDark,
                    highlight: Color(220, 100, 80))
    // Flagpole + flag on top
    drawFlag(p, poleX: towerX + towerW / 2, poleTopY: towerY - 22, poleHeight: 14, frame: frame)
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

// MARK: - Constructing frames (scaffold overlay)

/// Per-kind body rectangle in the building canvas. Matches the
/// `body{X,Y,W,H}` locals in each `<kind>Sprite` function so the
/// scaffold cage lines up with the actual walls.
struct BodyRectInCanvas { let x: Int; let y: Int; let w: Int; let h: Int }

enum BuildingKindRaw: String, CaseIterable {
    case house
    case warehouse
    case road
    case lumberjackHut = "lumberjack_hut"
    case sawmill
    case townCenter = "town_center"
}

/// Compute the body rect for a kind from its canonical sprite. Mirrors
/// the `bodyX/bodyY/bodyW/bodyH` math inside each per-kind sprite fn.
func bodyRect(for kind: BuildingKindRaw, canvasW: Int, canvasH: Int) -> BodyRectInCanvas {
    switch kind {
    case .house:
        let footprintH = 2
        let tileH = footprintH * 32
        let baseY = canvasH - tileH
        let bodyH = 30
        let bodyW = 56
        let bodyX = (canvasW - bodyW) / 2
        let bodyBottom = baseY + tileH / 2
        return BodyRectInCanvas(x: bodyX, y: bodyBottom - bodyH, w: bodyW, h: bodyH)
    case .warehouse:
        let footprintH = 3
        let tileH = footprintH * 32
        let baseY = canvasH - tileH
        let bodyH = 44
        let bodyW = 96
        let bodyX = (canvasW - bodyW) / 2
        let bodyBottom = baseY + tileH / 2
        return BodyRectInCanvas(x: bodyX, y: bodyBottom - bodyH, w: bodyW, h: bodyH)
    case .lumberjackHut:
        let footprintH = 2
        let tileH = footprintH * 32
        let baseY = canvasH - tileH
        let bodyH = 26
        let bodyW = 52
        let bodyX = (canvasW - bodyW) / 2
        let bodyBottom = baseY + tileH / 2
        return BodyRectInCanvas(x: bodyX, y: bodyBottom - bodyH, w: bodyW, h: bodyH)
    case .sawmill:
        let footprintH = 2
        let tileH = footprintH * 32
        let baseY = canvasH - tileH
        let bodyH = 30
        let bodyW = 56
        let bodyX = (canvasW - bodyW) / 2
        let bodyBottom = baseY + tileH / 2
        return BodyRectInCanvas(x: bodyX, y: bodyBottom - bodyH, w: bodyW, h: bodyH)
    case .townCenter:
        let footprintH = 3
        let tileH = footprintH * 32
        let baseY = canvasH - tileH
        let bodyH = 56
        let bodyW = 104
        let bodyX = (canvasW - bodyW) / 2
        let bodyBottom = baseY + tileH / 2
        return BodyRectInCanvas(x: bodyX, y: bodyBottom - bodyH, w: bodyW, h: bodyH)
    case .road:
        // Road is 1×1, no body. Scaffold covers a small mound on the tile.
        let bodyW = 32
        let bodyH = 14
        let bodyX = (canvasW - bodyW) / 2
        let bodyY = canvasH - 32 + 2
        return BodyRectInCanvas(x: bodyX, y: bodyY, w: bodyW, h: bodyH)
    }
}

func baseBuilding(for kind: BuildingKindRaw) -> Pixmap {
    switch kind {
    case .house: return houseSprite()
    case .warehouse: return warehouseSprite()
    case .lumberjackHut: return lumberjackHutSprite()
    case .sawmill: return sawmillSprite()
    case .townCenter: return townCenterSprite()
    case .road: return roadSprite()
    }
}

func constructingFrame(for kind: BuildingKindRaw, stage: Int) -> Pixmap {
    let base = baseBuilding(for: kind)
    let rect = bodyRect(for: kind, canvasW: base.width, canvasH: base.height)
    drawScaffold(
        base,
        bodyX: rect.x, bodyY: rect.y, bodyW: rect.w, bodyH: rect.h,
        stage: stage, totalStages: 3
    )
    return base
}

// MARK: - Walker sprites (8×12 each, 4 facings × 2 frames = 8 PNGs)

enum Facing: String, CaseIterable {
    case ne, se, sw, nw
    var tunicColor: Color {
        switch self {
        case .ne: return Color(180, 60, 50)   // red tunic
        case .se: return Color(180, 140, 80)  // brown tunic
        case .sw: return Color(80, 100, 180)  // blue tunic
        case .nw: return Color(150, 110, 70)  // tan tunic
        }
    }
}

func walkerSprite(facing: Facing, frame: Int) -> Pixmap {
    let p = Pixmap(width: 8, height: 12)
    let skin = Color(232, 196, 152)
    let hair = Color(80, 50, 28)
    let tunic = facing.tunicColor
    let tunicShade = tunic.darker(40)
    let pants = Color(64, 50, 36)
    let outline = P.outline
    let sack = Color(140, 110, 60)
    let sackShade = sack.darker(40)

    // Head (3×3 with hair on top, centered cols 2-4).
    p.fillRect(x: 2, y: 1, w: 3, h: 2, skin)
    // Hair (1 px on top row, slight forelock).
    p.set(2, 0, hair); p.set(3, 0, hair); p.set(4, 0, hair)
    p.set(2, 1, hair) // forelock on the sun-facing side
    // Head outline
    p.set(1, 1, outline); p.set(5, 1, outline)
    p.set(1, 2, outline); p.set(5, 2, outline)
    p.set(2, 3, outline); p.set(4, 3, outline)
    // Eyes (single dark pixel each) — only on N-facing variants since
    // S-facing shows the back of the head.
    if facing == .ne || facing == .nw {
        p.set(2, 2, outline)
        p.set(4, 2, outline)
    }

    // Body / tunic (cols 1-5, rows 4-7).
    p.fillRect(x: 1, y: 4, w: 5, h: 4, tunic)
    // Tunic shading: the right column gets a darker shade (shadow side).
    for dy in 0 ..< 4 { p.set(5, 4 + dy, tunicShade) }
    // Belt at the bottom of the tunic.
    for dx in 1 ... 5 { p.set(dx, 7, outline) }
    // Outline body sides
    for dy in 0 ..< 4 {
        p.set(0, 4 + dy, outline)
        p.set(6, 4 + dy, outline)
    }
    // Arms (skin tone pixels just outside the tunic).
    p.set(0, 5, skin); p.set(6, 5, skin)
    p.set(0, 6, outline); p.set(6, 6, outline)

    // Sack on shoulder (NW corner of the body).
    p.fillRect(x: 1, y: 3, w: 2, h: 2, sack)
    p.set(0, 3, outline); p.set(3, 3, outline)
    p.set(1, 4, sackShade)

    // Legs / feet. Frame 0 = mid-stride, frame 1 = legs apart.
    let legColor = pants
    if frame == 0 {
        // Both legs together-ish (stride passing through center).
        p.fillRect(x: 2, y: 8, w: 1, h: 3, legColor)
        p.fillRect(x: 4, y: 8, w: 1, h: 3, legColor)
        // Feet.
        p.set(1, 11, outline); p.set(2, 11, outline)
        p.set(4, 11, outline); p.set(5, 11, outline)
    } else {
        // Legs apart (one forward, one back) — distinct walking pose.
        p.fillRect(x: 1, y: 8, w: 1, h: 2, legColor)
        p.set(1, 10, legColor)
        p.fillRect(x: 5, y: 8, w: 1, h: 2, legColor)
        p.set(5, 10, legColor)
        // Feet.
        p.set(0, 10, outline); p.set(1, 10, outline)
        p.set(5, 10, outline); p.set(6, 10, outline)
    }

    return p
}

// MARK: - Main

/// Resolve the output root. If a single positional CLI argument is
/// provided, treat it as the root directory under which the category
/// atlases live. Otherwise default to `<cwd>/Resources` (current repo
/// layout). The atlas-folder routing is performed by `atlasFolder(for:)`
/// based on sprite-name prefix.
let argv = CommandLine.arguments
let outputRoot: String = if argv.count >= 2 {
    URL(fileURLWithPath: argv[1]).standardizedFileURL.path
} else {
    "\(FileManager.default.currentDirectoryPath)/Resources"
}

func atlasFolder(for spriteName: String) -> String {
    if spriteName.hasPrefix("terrain-") { return "Terrain.atlas" }
    if spriteName.hasPrefix("building-") { return "Buildings.atlas" }
    if spriteName.hasPrefix("walker-") { return "Units.atlas" }
    fatalError("Unknown sprite-name prefix for routing: \(spriteName)")
}

func ensureAtlas(_ folder: String) {
    let path = "\(outputRoot)/\(folder)"
    try? FileManager.default.createDirectory(
        atPath: path, withIntermediateDirectories: true
    )
}

ensureAtlas("Terrain.atlas")
ensureAtlas("Buildings.atlas")
ensureAtlas("Units.atlas")

func write(_ sprite: Pixmap, name: String) {
    let folder = atlasFolder(for: name)
    sprite.savePNG(to: "\(outputRoot)/\(folder)/\(name).png")
}

print("Generating terrain sprites...")
write(grassSprite(), name: "terrain-grass")
write(forestSprite(), name: "terrain-forest")
write(beachSprite(), name: "terrain-beach")
write(waterSprite(), name: "terrain-water")
write(mountainSprite(), name: "terrain-mountain")

print("Generating building sprites...")
write(houseSprite(), name: "building-house")
write(warehouseSprite(), name: "building-warehouse")
write(lumberjackHutSprite(), name: "building-lumberjack_hut")
write(sawmillSprite(), name: "building-sawmill")
write(townCenterSprite(), name: "building-town_center")
write(roadSprite(), name: "building-road")

print("Generating walker sprites...")
for facing in Facing.allCases {
    for frame in 0 ... 1 {
        write(
            walkerSprite(facing: facing, frame: frame),
            name: "walker-\(facing.rawValue)-\(frame)"
        )
    }
}

print("Generating terrain idle-animation frames...")
for frame in 0 ... 3 {
    write(waterFrame(frame: frame), name: "terrain-water-\(frame)")
}
for frame in 0 ... 1 {
    write(beachFrame(frame: frame), name: "terrain-beach-\(frame)")
}
for frame in 0 ... 1 {
    write(grassFrame(frame: frame), name: "terrain-grass-\(frame)")
}

print("Generating building operational-animation frames...")
for frame in 0 ... 3 {
    write(sawmillSprite(frame: frame), name: "building-sawmill-operational-\(frame)")
}
for frame in 0 ... 1 {
    write(
        lumberjackHutSprite(frame: frame),
        name: "building-lumberjack_hut-operational-\(frame)"
    )
}
for frame in 0 ... 1 {
    write(townCenterSprite(frame: frame), name: "building-town_center-operational-\(frame)")
}

print("Generating building constructing-animation frames...")
for kind in BuildingKindRaw.allCases {
    for stage in 0 ... 2 {
        write(
            constructingFrame(for: kind, stage: stage),
            name: "building-\(kind.rawValue)-constructing-\(stage)"
        )
    }
}

print("Done. Atlases written under \(outputRoot)/")
