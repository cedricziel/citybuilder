import Foundation
import Testing

// Metadata tests for the cross-platform determinism CI gate (spec
// fixed-point-math, Requirement: Cross-platform determinism gate).
// The gate itself is implemented as three GitHub Actions jobs in
// .github/workflows/ci.yml — these tests assert the workflow file
// contains the expected job shape, so an accidental rename or
// removal trips a unit test rather than silently disabling the gate.

private func ciWorkflow() throws -> String {
    let root = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent() // CityCoreTests
        .deletingLastPathComponent() // Tests
        .deletingLastPathComponent() // CityCore
        .deletingLastPathComponent() // Packages
        .deletingLastPathComponent() // worktree root
    let path = root.appendingPathComponent(".github/workflows/ci.yml").path
    return try String(contentsOfFile: path, encoding: .utf8)
}

@Test("scenario: determinism gate blocks prs on divergence")
func scenarioDeterminismGateBlocksPrsOnDivergence() throws {
    let yml = try ciWorkflow()
    // A Linux-toolchain job runs the same fixture as macOS.
    #expect(yml.contains("determinism-linux"))
    #expect(yml.contains("swift:6.0-jammy"))
    // A compare job downloads both artifacts and diffs them — the
    // diff exits non-zero on divergence, which fails the workflow
    // and blocks merge.
    #expect(yml.contains("determinism-compare"))
    #expect(yml.contains("diff -q determinism/macos.json determinism/linux.json"))
}

@Test("scenario: determinism gate passes when math is platform-agnostic")
func scenarioDeterminismGatePassesWhenMathIsPlatformAgnostic() throws {
    let yml = try ciWorkflow()
    // Both producer jobs invoke the same DeterminismFixture target;
    // identical inputs through Fixed-point arithmetic produce
    // identical JSON, which the diff job confirms.
    #expect(yml.contains("DeterminismFixture > determinism/macos.json"))
    #expect(yml.contains("DeterminismFixture > determinism/linux.json"))
    // M10 adds the 60-minute (36000-tick) drift check. Both platforms
    // produce a parallel JSON whose hash is diffed alongside the
    // 6000-tick baseline.
    #expect(yml.contains("DeterminismFixture 36000 > determinism/macos-36k.json"))
    #expect(yml.contains("DeterminismFixture 36000 > determinism/linux-36k.json"))
    #expect(yml.contains("diff -q determinism/macos-36k.json determinism/linux-36k.json"))
    // The compare job is wired as a dependency of both producers so
    // it cannot run before they finish.
    #expect(yml.contains("needs: [test, determinism-linux]"))
}
