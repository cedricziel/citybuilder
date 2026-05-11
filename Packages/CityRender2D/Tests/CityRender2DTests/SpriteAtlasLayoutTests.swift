#if canImport(AppKit)
import Foundation
import Testing

// Filesystem + code-scan scenarios for the sprite-asset-pipeline and
// rendering-2_5d capabilities introduced by add-sprite-atlas-layout.
// Each `#### Scenario:` here is one filesystem or static check against
// the worktree on disk.

private func worktreeRoot() -> URL {
    URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent() // CityRender2DTests
        .deletingLastPathComponent() // Tests
        .deletingLastPathComponent() // CityRender2D
        .deletingLastPathComponent() // Packages
        .deletingLastPathComponent() // worktree root
}

@Test("scenario: terrain atlas exists")
func scenarioTerrainAtlasExists() {
    let url = worktreeRoot().appendingPathComponent("Resources/Terrain.atlas")
    var isDir: ObjCBool = false
    let exists = FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir)
    #expect(exists && isDir.boolValue, "Resources/Terrain.atlas must exist as a directory")
    // The catalog declares one terrain-<kind> base sprite for each
    // TerrainType plus animation frames; presence is exercised
    // exhaustively by the asset-presence scenarios. Here we just
    // confirm the atlas folder has at least one PNG.
    let contents = (try? FileManager.default.contentsOfDirectory(atPath: url.path)) ?? []
    #expect(contents.contains(where: { $0.hasPrefix("terrain-") && $0.hasSuffix(".png") }))
}

@Test("scenario: buildings atlas exists")
func scenarioBuildingsAtlasExists() {
    let url = worktreeRoot().appendingPathComponent("Resources/Buildings.atlas")
    var isDir: ObjCBool = false
    let exists = FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir)
    #expect(exists && isDir.boolValue, "Resources/Buildings.atlas must exist as a directory")
    let contents = (try? FileManager.default.contentsOfDirectory(atPath: url.path)) ?? []
    #expect(contents.contains(where: { $0.hasPrefix("building-") && $0.hasSuffix(".png") }))
}

@Test("scenario: units atlas exists")
func scenarioUnitsAtlasExists() {
    let url = worktreeRoot().appendingPathComponent("Resources/Units.atlas")
    var isDir: ObjCBool = false
    let exists = FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir)
    #expect(exists && isDir.boolValue, "Resources/Units.atlas must exist as a directory")
    let contents = (try? FileManager.default.contentsOfDirectory(atPath: url.path)) ?? []
    #expect(contents.contains(where: { $0.hasPrefix("walker-") && $0.hasSuffix(".png") }))
}

@Test("scenario: legacy sprite directory removed")
func scenarioLegacySpriteDirectoryRemoved() {
    let url = worktreeRoot().appendingPathComponent("Resources/Sprites")
    #expect(!FileManager.default.fileExists(atPath: url.path), "Resources/Sprites/ must not exist")
}

@Test("scenario: renderer source uses spriteatlas exclusively")
func scenarioRendererSourceUsesSpriteAtlasExclusively() throws {
    // Code-scan every .swift file under Packages/CityRender2D/Sources/
    // and confirm none calls `SKTexture(imageNamed:` for catalogued
    // sprite assets. Comments are stripped before the check so doc
    // text mentioning the forbidden call (in a "never use this"
    // context) doesn't trip the gate.
    let root = worktreeRoot()
        .appendingPathComponent("Packages/CityRender2D/Sources/CityRender2D")
    let enumerator = FileManager.default.enumerator(
        at: root, includingPropertiesForKeys: nil
    )
    var violations: [String] = []
    while let url = enumerator?.nextObject() as? URL {
        guard url.pathExtension == "swift" else { continue }
        let source = try String(contentsOf: url, encoding: .utf8)
        let codeLines = source.split(separator: "\n", omittingEmptySubsequences: false)
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            .joined(separator: "\n")
        if codeLines.contains("SKTexture(imageNamed:") {
            violations.append(url.lastPathComponent)
        }
    }
    if !violations.isEmpty {
        Issue.record(
            "files calling SKTexture(imageNamed:) directly: \(violations.joined(separator: ", "))"
        )
    }
    #expect(violations.isEmpty)
}
#endif
