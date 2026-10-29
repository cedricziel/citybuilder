#if canImport(AppKit)
import CityCore
import Foundation
import Testing
@testable import CityRender2D

// Markdown shape scenarios for the sprite-style-catalog capability, as
// replace-generative-sprites-with-isokit leaves it: the kit's style bible
// and one brief per sprite kind. Each `@Test("scenario: ...")` maps to a
// `#### Scenario:` of that capability. The tests parse the committed
// Markdown on disk; they render nothing.

private func worktreeRoot() -> URL {
    URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent() // CityRender2DTests
        .deletingLastPathComponent() // Tests
        .deletingLastPathComponent() // CityRender2D
        .deletingLastPathComponent() // Packages
        .deletingLastPathComponent() // worktree root
}

private func readFile(_ relative: String) throws -> String {
    let url = worktreeRoot().appendingPathComponent(relative)
    return try String(contentsOf: url, encoding: .utf8)
}

/// Extracts the text of all level-2 ATX headings (`## Heading`) from a
/// Markdown blob. Trims surrounding whitespace. Handles `##` and `## `.
/// Ignores `###`, `####`, etc.
private func level2Headings(in markdown: String) -> [String] {
    var out: [String] = []
    for raw in markdown.split(separator: "\n", omittingEmptySubsequences: false) {
        let line = raw.trimmingCharacters(in: .whitespaces)
        guard line.hasPrefix("## "), !line.hasPrefix("### ") else { continue }
        let title = String(line.dropFirst(3)).trimmingCharacters(in: .whitespaces)
        if !title.isEmpty { out.append(title) }
    }
    return out
}

/// Returns the body of the named level-2 section, or nil if absent.
private func sectionBody(_ heading: String, in markdown: String) -> String? {
    let lines = markdown.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
    var inSection = false
    var collected: [String] = []
    for line in lines {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        if trimmed.hasPrefix("## ") {
            let title = String(trimmed.dropFirst(3)).trimmingCharacters(in: .whitespaces)
            if inSection { break }
            if title == heading { inSection = true; continue }
        }
        if inSection { collected.append(line) }
    }
    return inSection ? collected.joined(separator: "\n") : nil
}

// MARK: - Requirement: Style bible declares the kit's visual identity

@Test("scenario: style bible declares all required sections")
func scenarioStyleBibleDeclaresAllRequiredSections() throws {
    let body = try readFile("Resources/Sprites.style/world.md")
    let headings = Set(level2Headings(in: body))
    let required: Set = [
        "Theme & era", "Visual references", "Projection & scale", "Light rig", "Finishes & tiers", "Terrain", "Animation",
        "Forbidden"
    ]
    let missing = required.subtracting(headings)
    #expect(missing.isEmpty, "world.md is missing required sections: \(missing.sorted())")
}

@Test("scenario: style bible forbids image generation")
func scenarioStyleBibleForbidsImageGeneration() throws {
    let body = try readFile("Resources/Sprites.style/world.md")
    let forbidden = try #require(sectionBody("Forbidden", in: body)).lowercased()
    #expect(forbidden.contains("image-generation"), "the Forbidden section must rule out image-generation models")
}

// MARK: - Per-sprite catalog enumeration & parsing helpers

/// The set of catalog IDs the project's sprite kinds require, derived
/// directly from the code-side enums. Used as the source of truth for
/// "every code-declared sprite kind has a catalog entry".
@MainActor
private func expectedCatalogIds() -> Set<String> {
    var ids: Set<String> = []
    for terrain in TerrainType.allCases {
        ids.insert("terrain-\(terrain.rawValue)")
    }
    for building in BuildingKind.allCases {
        let raw = building.rawValue
        if SpriteName.shorePlacementKindRawValues.contains(raw) {
            for orientation in SpriteName.shoreOrientations {
                ids.insert("building-\(raw)-\(orientation)")
            }
        } else {
            ids.insert("building-\(raw)")
        }
    }
    // Culture looks (`add-cultures`) and seasonal vegetation
    // (`add-calendar-and-events`) have their own entries.
    for culture in Culture.allCases where culture != .northernEuropean {
        for kind in IsoWorldScene.cultureVariantKinds {
            ids.insert("building-\(kind.rawValue)-\(culture.rawValue)")
        }
    }
    // Age house looks (`add-historical-ages`): one entry per non-medieval
    // age and culture, holding all three house tiers.
    for age in Age.allCases where age != .medieval {
        for culture in Culture.allCases {
            let suffix = culture == .northernEuropean ? "" : "-\(culture.rawValue)"
            ids.insert("building-house-\(age.rawValue)\(suffix)")
        }
    }
    for terrain in IsoWorldScene.seasonalTerrain {
        for season in [Season.autumn, .winter] {
            if let name = IsoWorldScene.seasonalTerrainName(kind: terrain, season: season) { ids.insert(name) }
        }
    }
    // The status badge drawn over a waiting construction site.
    ids.insert(IsoWorldScene.waitingBadgeNodeName)
    // The building status icons, one brief for every good's icons and the issue pictograms.
    ids.insert("status-icons")
    ids.insert("walker")
    ids.insert("animal")
    ids.insert("ship")
    for good in Good.allCases {
        ids.insert("good-\(good.rawValue)")
    }
    return ids
}

private func catalogFiles() throws -> [URL] {
    let dir = worktreeRoot().appendingPathComponent("Resources/Sprites.style/catalog")
    guard FileManager.default.fileExists(atPath: dir.path) else { return [] }
    let contents = try FileManager.default.contentsOfDirectory(
        at: dir, includingPropertiesForKeys: nil
    )
    return contents.filter { $0.pathExtension == "md" }.sorted { $0.path < $1.path }
}

// MARK: - Requirement: Per-sprite catalog covers every sprite kind

@MainActor
@Test("scenario: every code-declared sprite kind has a catalog entry")
func scenarioEveryCodeDeclaredSpriteKindHasACatalogEntry() {
    let dir = worktreeRoot().appendingPathComponent("Resources/Sprites.style/catalog")
    let expected = expectedCatalogIds()
    var missing: [String] = []
    for id in expected.sorted() {
        let url = dir.appendingPathComponent("\(id).md")
        if !FileManager.default.fileExists(atPath: url.path) {
            missing.append(id)
        }
    }
    #expect(missing.isEmpty, "missing catalog entries: \(missing.joined(separator: ", "))")
}

@MainActor
@Test("scenario: no orphan catalog entries")
func scenarioNoOrphanCatalogEntries() throws {
    let files = try catalogFiles()
    let expected = expectedCatalogIds()
    var orphans: [String] = []
    for url in files {
        let id = url.deletingPathExtension().lastPathComponent
        if !expected.contains(id) { orphans.append(id) }
    }
    #expect(orphans.isEmpty, "orphan catalog entries: \(orphans.joined(separator: ", "))")
}

// MARK: - Requirement: Catalog entry declares function, identity, sheet, animation

/// Every brief names its sprites and how they are made.
@Test("scenario: catalog entry declares all required sections")
func scenarioCatalogEntryDeclaresAllRequiredSections() throws {
    let files = try catalogFiles()
    #expect(!files.isEmpty)
    var failures: [String] = []
    for url in files {
        let body = try String(contentsOf: url, encoding: .utf8)
        let missing = Set(["Function", "Visual identity", "Sprites", "Recipe"]).subtracting(Set(level2Headings(in: body)))
        if !missing.isEmpty {
            failures.append("\(url.lastPathComponent): missing \(missing.sorted())")
        }
    }
    #expect(failures.isEmpty, "catalog files missing sections:\n\(failures.joined(separator: "\n"))")
}

// MARK: - Requirement: One rendered register for world sprites

@Test("scenario: every building and unit entry is rendered by isokit")
func scenarioEveryBuildingAndUnitEntryIsRenderedByIsoKit() throws {
    let wrong = try catalogFiles().filter { url in
        let id = url.deletingPathExtension().lastPathComponent
        // Roads are drawn by the road generator, an SVG source.
        guard id.hasPrefix("building-") && id != "building-road" || ["walker", "animal", "ship"].contains(id) else { return false }
        if pendingCatalogIds.contains(id) { return false }
        return try catalogSource(of: String(contentsOf: url, encoding: .utf8)) != "isokit"
    }
    #expect(wrong.isEmpty, "\(wrong.map(\.lastPathComponent))")
}

@Test("scenario: Terrain entries and goods icons are SVG")
func scenarioTerrainAndGoodsAreSVG() throws {
    for url in try catalogFiles() {
        let id = url.deletingPathExtension().lastPathComponent
        let source = try catalogSource(of: String(contentsOf: url, encoding: .utf8))
        if id.hasPrefix("terrain-") || id.hasPrefix("good-") || id == "building-road" {
            #expect(source == "svg", "\(id) is \(source)")
        }
    }
}

/// The briefs of the kinds still waiting for their art (`PendingArt`).
private let pendingCatalogIds = Set(PendingArt.buildingKinds.map { "building-\($0.rawValue)" })

@Test("pending art is pending in the catalog and has no sprites yet")
func pendingArtHasNoSpritesYet() throws {
    let kit = worktreeRoot().appendingPathComponent("Resources/Kit.atlas")
    let committed = (try? FileManager.default.contentsOfDirectory(atPath: kit.path)) ?? []
    for id in pendingCatalogIds.sorted() {
        let url = worktreeRoot().appendingPathComponent("Resources/Sprites.style/catalog/\(id).md")
        let source = try catalogSource(of: String(contentsOf: url, encoding: .utf8))
        #expect(source == "pending", "\(id) is \(source): drop it from PendingArt")
        let drawn = committed.filter { $0.hasPrefix(id + ".") || $0.hasPrefix(id + "@") || $0.hasPrefix(id + "-") }
        #expect(drawn.isEmpty, "\(id) has sprites \(drawn): drop it from PendingArt")
    }
    let pending = try catalogFiles().filter { try catalogSource(of: String(contentsOf: $0, encoding: .utf8)) == "pending" }
    #expect(Set(pending.map { $0.deletingPathExtension().lastPathComponent }) == pendingCatalogIds)
}

/// `source = "<value>"` from the front matter, or "" for image-API briefs.
private func catalogSource(of body: String) -> String {
    for line in body.split(separator: "\n").prefix(5) where line.hasPrefix("source = ") {
        return line.dropFirst("source = ".count).trimmingCharacters(in: CharacterSet(charactersIn: "\""))
    }
    return ""
}

#endif
