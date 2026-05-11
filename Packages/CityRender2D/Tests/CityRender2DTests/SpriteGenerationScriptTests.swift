#if canImport(AppKit)
import Foundation
import Testing

// Harness tests for `scripts/generate-sprites.swift`. The script ships
// as a `#!/usr/bin/env swift` file run via `swift scripts/...`; here we
// invoke it through `Process` against a temp output root and assert
// that PNGs land in the new category-atlas folders rather than a flat
// directory. Only the routing contract is asserted — pixel content is
// covered separately by the bit-identical check (task 1.3).

private func repoRoot() -> URL {
    URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent() // CityRender2DTests
        .deletingLastPathComponent() // Tests
        .deletingLastPathComponent() // CityRender2D
        .deletingLastPathComponent() // Packages
        .deletingLastPathComponent() // worktree root
}

private func runGenerator(outputRoot: URL) throws -> Int32 {
    let script = repoRoot().appendingPathComponent("scripts/generate-sprites.swift").path
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
    process.arguments = ["swift", script, outputRoot.path]
    process.standardOutput = Pipe()
    process.standardError = Pipe()
    try process.run()
    process.waitUntilExit()
    return process.terminationStatus
}

@Test("scenario: generate script routes outputs to category atlases")
func scenarioGenerateScriptRoutesOutputsToCategoryAtlases() throws {
    let tmp = FileManager.default.temporaryDirectory
        .appendingPathComponent("sprite-gen-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: tmp) }

    let status = try runGenerator(outputRoot: tmp)
    #expect(status == 0, "generate-sprites.swift exited with status \(status)")

    let expected: [(folder: String, file: String)] = [
        ("Terrain.atlas", "terrain-grass.png"),
        ("Terrain.atlas", "terrain-water-3.png"),
        ("Terrain.atlas", "terrain-beach-1.png"),
        ("Buildings.atlas", "building-sawmill.png"),
        ("Buildings.atlas", "building-house-constructing-0.png"),
        ("Buildings.atlas", "building-sawmill-operational-2.png"),
        ("Units.atlas", "walker-ne-0.png"),
        ("Units.atlas", "walker-sw-1.png")
    ]
    for entry in expected {
        let path = tmp.appendingPathComponent(entry.folder)
            .appendingPathComponent(entry.file).path
        #expect(
            FileManager.default.fileExists(atPath: path),
            "expected \(entry.folder)/\(entry.file)"
        )
    }

    // The flat layout must NOT be written anymore.
    let flat = tmp.appendingPathComponent("Sprites").path
    #expect(!FileManager.default.fileExists(atPath: flat), "flat Sprites/ must not exist")
}
#endif
