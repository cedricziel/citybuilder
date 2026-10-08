#if canImport(ImageIO)
import Foundation
import SpriteContentGate
import Testing

private func worktreeRoot() -> URL {
    URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent() // SpriteContentGateTests
        .deletingLastPathComponent() // Tests
        .deletingLastPathComponent() // CityRender2D
        .deletingLastPathComponent() // Packages
        .deletingLastPathComponent() // worktree root
}

@Suite("Committed terrain art")
struct CommittedTerrainArtTests {
    @Test("scenario: every committed terrain sprite fills the diamond")
    func committedTerrainFillsDiamond() throws {
        let atlas = worktreeRoot().appendingPathComponent("Resources/Terrain.atlas")
        let files = try FileManager.default.contentsOfDirectory(at: atlas, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "png" }
        #expect(!files.isEmpty)
        for file in files {
            let metrics = try DiamondMetrics(of: RGBAImage(contentsOf: file))
            #expect(metrics.coverage >= SpriteContentGate.minimumTerrainCoverage, "\(file.lastPathComponent)")
            #expect(metrics.outsideRatio <= SpriteContentGate.maximumOutsideRatio, "\(file.lastPathComponent)")
        }
    }

    @Test("scenario: committed building sprites pass outline and grounding checks")
    func committedBuildingsPassRegisterChecks() throws {
        let failures = try SpriteContentGate.inspect(
            resourcesRoot: worktreeRoot().appendingPathComponent("Resources"),
            coherenceMaxDistance: 0.3
        )
        let register = failures.filter { $0.reason == .outlineMissing || $0.reason == .notGrounded }
        #expect(register.isEmpty, "\(register)")
    }

    @Test("scenario: every building and unit entry is procedural")
    func everyBuildingAndUnitEntryIsProcedural() throws {
        let catalog = worktreeRoot().appendingPathComponent("Resources/Sprites.style/catalog")
        let entries = try FileManager.default.contentsOfDirectory(at: catalog, includingPropertiesForKeys: nil)
            .filter { url in
                let name = url.deletingPathExtension().lastPathComponent
                return name.hasPrefix("building-") || name == "walker" || name == "ship"
            }
        #expect(entries.count >= 15)
        for entry in entries {
            let text = try String(contentsOf: entry, encoding: .utf8)
            #expect(text.hasPrefix("---\nsource = \"procedural\"\n---\n"), "\(entry.lastPathComponent)")
        }
    }

    @Test("scenario: style bible pins the building register")
    func styleBiblePinsTheBuildingRegister() throws {
        let world = try String(
            contentsOf: worktreeRoot().appendingPathComponent("Resources/Sprites.style/world.md"),
            encoding: .utf8
        )
        #expect(world.split(separator: "\n").contains("## Building register"))
    }
}
#endif
