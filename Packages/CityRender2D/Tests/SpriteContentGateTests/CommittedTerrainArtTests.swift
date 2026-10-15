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
        let atlas = worktreeRoot().appendingPathComponent("Resources/Kit.atlas")
        let files = try FileManager.default.contentsOfDirectory(at: atlas, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "png" && $0.lastPathComponent.hasPrefix("terrain-") }
        #expect(!files.isEmpty)
        for file in files {
            let fill = try DiamondFill(of: RGBAImage(contentsOf: file), bleedPoints: 1, scale: SpriteFile(file.lastPathComponent).scale)
            #expect(fill.holes == 0, "\(file.lastPathComponent) has \(fill.holes) hole(s) inside the diamond")
            #expect(fill.beyondBleed == 0, "\(file.lastPathComponent) reaches past the bleed")
        }
    }

    @Test("scenario: committed building sprites pass outline and grounding checks")
    func committedBuildingsPassRegisterChecks() throws {
        let failures = try SpriteContentGate.inspect(
            resourcesRoot: worktreeRoot().appendingPathComponent("Resources"),
            coherenceMaxDistance: 0.3
        )
        let register = failures.filter { $0.reason == .notGrounded }
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
            // Families migrate one at a time (replace-generative-sprites-with-isokit, tasks section 4):
            // until the last one flips, a brief is procedural, rendered by IsoKit, or drawn by an SVG
            // generator (roads).
            let source = ["procedural", "isokit", "svg"].first { text.hasPrefix("---\nsource = \"\($0)\"\n---\n") }
            #expect(source != nil, "\(entry.lastPathComponent)")
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
