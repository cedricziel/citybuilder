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
}
#endif
