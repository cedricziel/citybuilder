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
    // Variants (-v1) and house tier looks (-tier2) live in the base entry.
    let variantStripped = frameStripped.replacingOccurrences(
        of: "-(v|tier)[0-9]+$", with: "", options: .regularExpression
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

// MARK: - Requirement: Hermetic regeneration via make sprites

@Test("scenario: offline regen reproduces committed pngs")
func scenarioOfflineRegenReproducesCommittedPngs() throws {
    // Drives `make sprites-verify`, which redirects pipeline writes to
    // a tempdir, runs the pipeline offline against the committed
    // `_sheets/`, and exits non-zero on any byte mismatch against the
    // committed atlas PNGs.
    let process = Process()
    process.currentDirectoryURL = worktreeRoot()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
    process.arguments = ["make", "sprites-verify"]
    let pipe = Pipe()
    process.standardOutput = pipe
    process.standardError = pipe
    // Strip OPENAI_API_KEY from the test process so the verify step
    // also fails fast if it tries to call the API.
    var env = ProcessInfo.processInfo.environment
    env["OPENAI_API_KEY"] = ""
    process.environment = env
    try process.run()
    process.waitUntilExit()
    let output = String(
        data: pipe.fileHandleForReading.readDataToEndOfFile(),
        encoding: .utf8
    ) ?? ""
    #expect(
        process.terminationStatus == 0,
        "make sprites-verify exited \(process.terminationStatus):\n\(output)"
    )
}

@Test("scenario: ci fails on a cache miss")
func scenarioCiFailsOnACacheMiss() throws {
    // CI's reproducibility gate is `make sprites-verify`. The
    // scenario asserts that contributors who commit a catalog edit
    // without the matching sheet hit a hard CI failure. We assert
    // both anchors: `sprites-verify` must be a Makefile target, and
    // the catalog/sheet consistency hook must be wired into
    // pre-commit so the failure is caught before the push, not just
    // at CI time.
    let makefile = try readFile("Makefile")
    #expect(
        makefile.contains("sprites-verify:"),
        "Makefile must declare a `sprites-verify` target"
    )
    let preCommit = try readFile(".pre-commit-config.yaml")
    #expect(
        preCommit.contains("check-sprite-catalog-consistency"),
        "pre-commit must include the catalog-sheet consistency hook"
    )
    let ci = try readFile(".github/workflows/ci.yml")
    #expect(
        ci.contains("make sprites-verify"),
        "ci.yml must invoke make sprites-verify"
    )
}
#endif
