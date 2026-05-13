#if canImport(AppKit)
import CityCore
import CityRender2D
import Foundation
import Testing

// Filesystem + Markdown-shape scenarios for the sprite-style-catalog
// capability introduced by replace-procedural-sprites-with-ai-pipeline.
// Each `#### Scenario:` in the change's specs/sprite-style-catalog/spec.md
// maps to one `@Test("scenario: ...")` here. The tests parse the
// committed Markdown / TOML on disk; they do not invoke the pipeline.

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

// MARK: - Requirement: Style bible declares the world's visual identity

@Test("scenario: style bible file exists")
func scenarioStyleBibleFileExists() {
    let url = worktreeRoot().appendingPathComponent("Resources/Sprites.style/world.md")
    let exists = FileManager.default.fileExists(atPath: url.path)
    #expect(exists, "Resources/Sprites.style/world.md must exist")
    let attrs = (try? FileManager.default.attributesOfItem(atPath: url.path)) ?? [:]
    let size = (attrs[.size] as? NSNumber)?.intValue ?? 0
    #expect(size > 0, "world.md must be non-empty")
}

@Test("scenario: style bible declares all required sections")
func scenarioStyleBibleDeclaresAllRequiredSections() throws {
    let body = try readFile("Resources/Sprites.style/world.md")
    let headings = Set(level2Headings(in: body))
    let required: Set = [
        "Theme & era",
        "Visual references",
        "Projection & scale",
        "Palette",
        "Outline & shading",
        "Background",
        "Forbidden"
    ]
    let missing = required.subtracting(headings)
    #expect(missing.isEmpty, "world.md is missing required sections: \(missing.sorted())")
}

@Test("scenario: style bible declares the magenta chroma-key colour")
func scenarioStyleBibleDeclaresTheMagentaChromaKeyColour() throws {
    let body = try readFile("Resources/Sprites.style/world.md")
    guard let section = sectionBody("Background", in: body) else {
        Issue.record("world.md has no Background section")
        return
    }
    let normalised = section.lowercased()
    #expect(
        normalised.contains("#ff00ff"),
        "Background section must name the chroma-key colour #FF00FF"
    )
}

// MARK: - Requirement: Model version is pinned in the catalog

@Test("scenario: pipeline pins a dated model snapshot")
func scenarioPipelinePinsADatedModelSnapshot() throws {
    let body = try readFile("Resources/Sprites.style/pipeline.toml")
    // Look for a top-level `model = "..."` line. We don't need a full
    // TOML parser for one key; a regex is enough.
    let pattern = #"^\s*model\s*=\s*"([^"]+)"\s*$"#
    var matched: String?
    for raw in body.split(separator: "\n", omittingEmptySubsequences: false) {
        let line = String(raw)
        guard let range = line.range(of: pattern, options: .regularExpression) else { continue }
        let assignment = String(line[range])
        let quotes = assignment.indices.filter { assignment[$0] == "\"" }
        guard quotes.count >= 2 else { continue }
        matched = String(assignment[assignment.index(after: quotes[0]) ..< quotes[1]])
        break
    }
    guard let model = matched else {
        Issue.record("pipeline.toml has no `model = \"...\"` line")
        return
    }
    // Form: gpt-image-<major>-<YYYY>-<MM>-<DD>
    let snapshot = #"^gpt-image-\d+-\d{4}-\d{2}-\d{2}$"#
    #expect(
        model.range(of: snapshot, options: .regularExpression) != nil,
        "model id must be a dated snapshot, got \(model)"
    )
}

// MARK: - Per-sprite catalog enumeration & parsing helpers

/// The set of catalog IDs the project's sprite kinds require, derived
/// directly from the code-side enums. Used as the source of truth for
/// "every code-declared sprite kind has a catalog entry".
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
    ids.insert("walker")
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

private struct CatalogGrid {
    let cols: Int
    let rows: Int
}

/// Parses `Grid: N cols × M rows.` (or `Grid: N×M`) inside the body of
/// the `## Sheet` section. Returns nil if not found.
private func parseGrid(in sheetBody: String) -> CatalogGrid? {
    let pattern = #"Grid:\s*(\d+)\s*(?:cols?\s*[x×]\s*|[x×])\s*(\d+)"#
    guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
        return nil
    }
    let range = NSRange(sheetBody.startIndex ..< sheetBody.endIndex, in: sheetBody)
    guard
        let match = regex.firstMatch(in: sheetBody, options: [], range: range),
        match.numberOfRanges >= 3,
        let r1 = Range(match.range(at: 1), in: sheetBody),
        let r2 = Range(match.range(at: 2), in: sheetBody),
        let cols = Int(sheetBody[r1]),
        let rows = Int(sheetBody[r2])
    else { return nil }
    return CatalogGrid(cols: cols, rows: rows)
}

/// Extracts every distinct `(row, col)` coordinate pair from text.
private func parseCellCoords(in body: String) -> [(Int, Int)] {
    let pattern = #"\((\d+)\s*,\s*(\d+)\)"#
    guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
    let range = NSRange(body.startIndex ..< body.endIndex, in: body)
    var out: [(Int, Int)] = []
    regex.enumerateMatches(in: body, options: [], range: range) { match, _, _ in
        guard
            let match,
            match.numberOfRanges >= 3,
            let rowRange = Range(match.range(at: 1), in: body),
            let colRange = Range(match.range(at: 2), in: body),
            let row = Int(body[rowRange]),
            let col = Int(body[colRange])
        else { return }
        out.append((row, col))
    }
    return out
}

/// Extracts animation sequences from the Animation section body. A
/// sequence is a series of `(r, c) → (r, c) → ...` connected by an
/// arrow character (`→` or `->`). Returns an array of sequences, each a
/// list of (row, col) coordinates. An animation section containing no
/// arrow returns an empty array (representing a static sprite).
private func parseAnimationSequences(in body: String) -> [[(Int, Int)]] {
    var sequences: [[(Int, Int)]] = []
    for raw in body.split(separator: "\n", omittingEmptySubsequences: true) {
        let line = String(raw)
        // Must contain at least one arrow to be a sequence line.
        guard line.contains("→") || line.contains("->") else { continue }
        let coords = parseCellCoords(in: line)
        guard coords.count >= 2 else { continue }
        sequences.append(coords)
    }
    return sequences
}

// MARK: - Requirement: Per-sprite catalog covers every sprite kind

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

@Test("scenario: catalog entry declares all required sections")
func scenarioCatalogEntryDeclaresAllRequiredSections() throws {
    let files = try catalogFiles()
    let required: Set = ["Function", "Visual identity", "Sheet", "Animation"]
    var failures: [String] = []
    for url in files {
        let body = try String(contentsOf: url, encoding: .utf8)
        let headings = Set(level2Headings(in: body))
        let missing = required.subtracting(headings)
        if !missing.isEmpty {
            failures.append("\(url.lastPathComponent): missing \(missing.sorted())")
        }
    }
    #expect(failures.isEmpty, "catalog files missing sections:\n\(failures.joined(separator: "\n"))")
}

@Test("scenario: sheet section enumerates every cell")
func scenarioSheetSectionEnumeratesEveryCell() throws {
    let files = try catalogFiles()
    var failures: [String] = []
    for url in files {
        let body = try String(contentsOf: url, encoding: .utf8)
        guard let sheet = sectionBody("Sheet", in: body) else {
            failures.append("\(url.lastPathComponent): no Sheet section")
            continue
        }
        guard let grid = parseGrid(in: sheet) else {
            failures.append("\(url.lastPathComponent): Sheet missing `Grid: N cols × M rows`")
            continue
        }
        let cells = Set(parseCellCoords(in: sheet).map { "\($0.0),\($0.1)" })
        var expected: Set<String> = []
        for row in 0 ..< grid.rows {
            for col in 0 ..< grid.cols {
                expected.insert("\(row),\(col)")
            }
        }
        let missing = expected.subtracting(cells)
        let unexpected = cells.subtracting(expected)
        if !missing.isEmpty || !unexpected.isEmpty {
            failures.append(
                "\(url.lastPathComponent): missing=\(missing.sorted()) "
                    + "unexpected=\(unexpected.sorted())"
            )
        }
    }
    #expect(failures.isEmpty, "Sheet enumeration failures:\n\(failures.joined(separator: "\n"))")
}

// MARK: - Requirement: Master reference image anchors inter-sprite cohesion

@Test("scenario: master reference exists and is a png")
// swiftlint:disable:next inclusive_language
func scenarioMasterReferenceExistsAndIsAPng() {
    let url = worktreeRoot().appendingPathComponent(
        "Resources/Sprites.style/master-reference.png"
    )
    let exists = FileManager.default.fileExists(atPath: url.path)
    #expect(exists, "Resources/Sprites.style/master-reference.png must exist")
    let data = (try? Data(contentsOf: url, options: [.alwaysMapped])) ?? Data()
    // PNG signature: 89 50 4E 47 0D 0A 1A 0A
    let signature: [UInt8] = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]
    let head = Array(data.prefix(signature.count))
    #expect(head == signature, "master-reference must be a PNG; got first 8 bytes \(head)")
}

@Test("scenario: make sprites does not regenerate master reference")
// swiftlint:disable:next inclusive_language
func scenarioMakeSpritesDoesNotRegenerateMasterReference() throws {
    let url = worktreeRoot().appendingPathComponent(
        "Resources/Sprites.style/master-reference.png"
    )
    guard FileManager.default.fileExists(atPath: url.path) else {
        Issue.record("master-reference.png is absent; skipping mtime check")
        return
    }
    let attrsBefore = (try? FileManager.default.attributesOfItem(atPath: url.path)) ?? [:]
    let before = attrsBefore[.modificationDate] as? Date
    let process = Process()
    process.currentDirectoryURL = worktreeRoot()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
    process.arguments = ["make", "sprites-offline"]
    process.standardOutput = Pipe()
    process.standardError = Pipe()
    try process.run()
    process.waitUntilExit()
    let attrsAfter = (try? FileManager.default.attributesOfItem(atPath: url.path)) ?? [:]
    let after = attrsAfter[.modificationDate] as? Date
    #expect(before == after, "make sprites must not modify master-reference.png")
}

@Test("scenario: make sprites-reference is the only path to regenerate")
func scenarioMakeSpritesReferenceIsTheOnlyPathToRegenerate() throws {
    let makefile = try String(
        contentsOf: worktreeRoot().appendingPathComponent("Makefile"),
        encoding: .utf8
    )
    /// Find the recipe under target `sprites-reference:` and confirm it
    /// invokes the pipeline with --regenerate-reference. Other targets
    /// MUST NOT mention --regenerate-reference.
    func recipeFor(target: String) -> String {
        let lines = makefile.split(separator: "\n", omittingEmptySubsequences: false)
            .map(String.init)
        var collecting = false
        var collected: [String] = []
        for line in lines {
            if line.hasPrefix("\(target):") {
                collecting = true
                continue
            }
            if collecting {
                if line.first == "\t" { collected.append(line) } else if !line.isEmpty {
                    break
                }
            }
        }
        return collected.joined(separator: "\n")
    }
    let referenceRecipe = recipeFor(target: "sprites-reference")
    #expect(
        referenceRecipe.contains("--regenerate-reference"),
        "sprites-reference target must invoke pipeline with --regenerate-reference"
    )
    // No other target references --regenerate-reference.
    let lines = makefile.split(separator: "\n").map(String.init)
    let otherTargets = ["sprites:", "sprites-offline:", "sprites-verify:"]
    var violations: [String] = []
    for target in otherTargets {
        var collecting = false
        var collected: [String] = []
        for line in lines {
            if line.hasPrefix(target) {
                collecting = true
                continue
            }
            if collecting {
                if line.first == "\t" {
                    collected.append(line)
                } else if !line.isEmpty {
                    break
                }
            }
        }
        let recipe = collected.joined(separator: "\n")
        if recipe.contains("--regenerate-reference") {
            violations.append(target)
        }
    }
    #expect(
        violations.isEmpty,
        "non-reference target(s) regenerate master reference: \(violations)"
    )
}

@Test("scenario: animation frames are declared adjacent")
func scenarioAnimationFramesAreDeclaredAdjacent() throws {
    let files = try catalogFiles()
    var failures: [String] = []
    for url in files {
        let body = try String(contentsOf: url, encoding: .utf8)
        guard let animation = sectionBody("Animation", in: body) else { continue }
        let sequences = parseAnimationSequences(in: animation)
        for (idx, seq) in sequences.enumerated() {
            for step in 1 ..< seq.count {
                let (row0, col0) = seq[step - 1]
                let (row1, col1) = seq[step]
                let sharesAxis = row0 == row1 || col0 == col1
                let colDistOK = abs(col1 - col0) <= 1
                let rowDistOK = abs(row1 - row0) <= 1
                if !(sharesAxis && colDistOK && rowDistOK) {
                    failures.append(
                        "\(url.lastPathComponent) seq#\(idx): "
                            + "(\(row0),\(col0)) -> (\(row1),\(col1)) not adjacent"
                    )
                }
            }
        }
    }
    #expect(
        failures.isEmpty,
        "animation adjacency failures:\n\(failures.joined(separator: "\n"))"
    )
}
#endif
