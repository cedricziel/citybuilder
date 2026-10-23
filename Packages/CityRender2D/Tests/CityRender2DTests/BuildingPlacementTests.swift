#if canImport(ImageIO)
import Foundation
import ImageIO
import Testing

/// The alpha channel of a committed PNG, row 0 at the top.
private struct Alpha {
    let width: Int, height: Int, values: [UInt8]

    init?(_ url: URL) {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil),
              let context = CGContext(
                  data: nil, width: image.width, height: image.height, bitsPerComponent: 8, bytesPerRow: image.width * 4,
                  space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              ), let data = context.data
        else { return nil }
        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        width = image.width
        height = image.height
        let bytes = data.assumingMemoryBound(to: UInt8.self)
        values = (0 ..< width * height).map { bytes[$0 * 4 + 3] }
    }

    func opaque(_ column: Int, _ row: Int) -> Bool {
        values[row * width + column] > 0
    }
}

/// Footprint per building sprite, `(columns, rows)`, from each brief's `- Cell: C×R footprint` line and the
/// sprites it names.
private func footprints(catalog: URL) throws -> [String: (Int, Int)] {
    var result: [String: (Int, Int)] = [:]
    for brief in try FileManager.default.contentsOfDirectory(at: catalog, includingPropertiesForKeys: nil) {
        let text = try String(contentsOf: brief, encoding: .utf8)
        guard let cell = text.firstMatch(of: /- Cell: (\d+)×(\d+) footprint/), let cols = Int(cell.1), let rows = Int(cell.2)
        else { continue }
        for match in text.matches(of: /`(building-[a-z0-9-]+)`/) {
            result[String(match.1)] = (cols, rows)
        }
    }
    return result
}

/// Every building sprite stands on its footprint's bottom vertex, at the bottom of its cell, and its cell
/// is wide enough for its shadow: only the plot's left and right corners may touch the sides.
@Test("every building sprite stands on its anchor, with its shadow inside the cell")
func buildingSpritesSitOnTheirAnchor() throws {
    let resources = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent("Resources")
    let footprint = try footprints(catalog: resources.appendingPathComponent("Sprites.style/catalog"))
    let files = try FileManager.default.contentsOfDirectory(
        at: resources.appendingPathComponent("Kit.atlas"), includingPropertiesForKeys: nil
    ).filter {
        let name = $0.lastPathComponent
        // Roads lie flat across the whole tile; night lights hold only window panes.
        return name.hasPrefix("building-") && !name.hasPrefix("building-road") && !name.contains("-lights")
    }
    #expect(files.count > 300)
    var problems: [String] = []
    for file in files {
        let alpha = try #require(Alpha(file), "\(file.lastPathComponent)")
        let scale = file.lastPathComponent.contains("@2x") ? 2 : 1
        let stem = file.deletingPathExtension().lastPathComponent.replacingOccurrences(of: "@2x", with: "")
        let (cols, rows) = footprint[stem] ?? (2, 2)
        // The bottom vertex: the cell's centre, moved half a tile per column the footprint is short of rows.
        let vertex = Double(alpha.width) / 2 + Double((cols - rows) * 16 * scale)
        let span = (0 ..< alpha.width).filter { alpha.opaque($0, alpha.height - 1) }
        if let first = span.first, let last = span.last {
            // A shadow can reach the bottom row, but only to the vertex's right.
            let covers = Double(first) <= vertex + 0.5 && Double(last) >= vertex - 1.5
            if !covers || Double(first) < vertex - Double(3 * scale) - 1 {
                problems.append("\(file.lastPathComponent): bottom row \(first)…\(last), vertex at \(vertex)")
            }
        } else {
            problems.append("\(file.lastPathComponent): bottom row is empty")
        }
        // A plot corner touches a side for a few rows; a clipped shadow runs down it much further.
        for side in [0, alpha.width - 1] {
            let touching = (0 ..< alpha.height).count(where: { alpha.opaque(side, $0) })
            if touching > 4 * scale { problems.append("\(file.lastPathComponent): \(touching) rows touch column \(side)") }
        }
    }
    #expect(problems.isEmpty, "\(problems.sorted().joined(separator: "\n"))")
}
#endif
