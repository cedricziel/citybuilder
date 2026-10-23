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
            .filter { !SpriteContentGate.isTerrainObject($0.lastPathComponent) }
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
}
#endif
