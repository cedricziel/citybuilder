#if canImport(AppKit)
import Foundation
import Testing

// Cutover scenarios from replace-procedural-sprites-with-ai-pipeline:
//
// - `sprite-asset-pipeline` § "PNG contents are produced by the
//   style-catalog pipeline" (every committed atlas PNG routes back
//   to a catalog entry).
// - `sprite-asset-pipeline` § "Procedural sprite generator is retired"
//   (the legacy path is empty; Makefile and README contain no
//   references to the retired generator).
//
// Sits in its own file so `SpritesStyleCatalogTests.swift` stays under
// the 500-line SwiftLint cap. Helper functions are intentionally
// duplicated rather than extracted to a shared utility — they're
// small and local cohesion beats cross-file coupling here.

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

// MARK: - Requirement: PNG contents are produced by the style-catalog pipeline

/// Map a committed sprite-name back to its catalog id (the catalog
/// file basename, without the per-frame / per-state / per-variant
/// suffix). Mirrors the inverse of `slice_plan` in the Python pipeline.
private func catalogId(forSpriteName name: String) -> String {
    if name.hasPrefix("walker-") { return "walker" }
    if name.hasPrefix("ship-") { return "ship" }
    if name.hasPrefix("good-") { return name } // good-wood etc.
    // Strip animation/variant/state suffixes from terrain & building names.
    // Strategy: strip a trailing -<digit>+ (frame), then -v<digit>+ (variant),
    // then -(constructing|operational)$ (state without explicit frame).
    let frameStripped = name.replacingOccurrences(
        of: "-[0-9]+$", with: "", options: .regularExpression
    )
    let variantStripped = frameStripped.replacingOccurrences(
        of: "-v[0-9]+$", with: "", options: .regularExpression
    )
    return variantStripped.replacingOccurrences(
        of: "-(constructing|operational)$", with: "", options: .regularExpression
    )
}

@Test("scenario: every committed atlas png has a catalog entry")
func scenarioEveryCommittedAtlasPngHasACatalogEntry() {
    let atlases = [
        "Resources/Terrain.atlas",
        "Resources/Buildings.atlas",
        "Resources/Units.atlas",
        "Resources/Icons.atlas"
    ]
    let catalogDir = worktreeRoot().appendingPathComponent("Resources/Sprites.style/catalog")
    var missing: [String] = []
    for atlas in atlases {
        let dir = worktreeRoot().appendingPathComponent(atlas)
        guard let entries = try? FileManager.default.contentsOfDirectory(atPath: dir.path)
        else { continue }
        for entry in entries where entry.hasSuffix(".png") {
            let stem = (entry as NSString).deletingPathExtension
            // The overlay-* family is renderer-internal, not a catalog
            // entry — skip the routing check for it.
            if stem.hasPrefix("overlay-") { continue }
            let id = catalogId(forSpriteName: stem)
            let catalog = catalogDir.appendingPathComponent("\(id).md")
            if !FileManager.default.fileExists(atPath: catalog.path) {
                missing.append("\(entry) -> \(id).md")
            }
        }
    }
    #expect(missing.isEmpty, "atlas PNGs without a catalog entry: \(missing)")
}

// MARK: - Requirement: Procedural sprite generator is retired

@Test("scenario: legacy path is empty")
func scenarioLegacyPathIsEmpty() {
    let url = worktreeRoot().appendingPathComponent("scripts/generate-sprites.swift")
    #expect(
        !FileManager.default.fileExists(atPath: url.path),
        "scripts/generate-sprites.swift must not exist (legacy path quarantined to scripts/legacy/)"
    )
}

@Test("scenario: makefile references no procedural targets")
func scenarioMakefileReferencesNoProceduralTargets() throws {
    let body = try readFile("Makefile")
    let needle = "generate-sprites.swift"
    #expect(
        !body.contains(needle),
        "Makefile references the retired procedural generator"
    )
}

@Test("scenario: readme references no procedural workflow")
func scenarioReadmeReferencesNoProceduralWorkflow() throws {
    let body = try readFile("README.md")
    let needle = "generate-sprites.swift"
    #expect(
        !body.contains(needle),
        "README.md references the retired procedural generator"
    )
}
#endif
