import Foundation
import Testing
@testable import CityAudio

// Tests for spec `audio-playback` — `CityAudio package boundary` requirement.
// The actual link-time invariants are mechanically enforced by:
//   - project.yml (which targets list CityAudio as a dependency)
//   - scripts/check-cli-no-audio.sh (pre-link source scan)
// These tests mirror those checks in Swift so the scenario coverage
// script has a direct mapping and so regressions surface in `make test`.

private func repoRoot() -> URL {
    URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent() // file → CityAudioTests/
        .deletingLastPathComponent() // CityAudioTests → Tests/
        .deletingLastPathComponent() // Tests → CityAudio/
        .deletingLastPathComponent() // CityAudio → Packages/
        .deletingLastPathComponent() // Packages → repo root
}

@Test("scenario: cli does not link audio")
func scenarioCliDoesNotLinkAudio() throws {
    // Source-level: no CLI Swift file imports AVFoundation or CityAudio.
    // This catches the mistake at the import statement, well before any
    // otool -L inspection of the built binary would.
    let cliDir = repoRoot().appendingPathComponent("CLI/citybuilder-cli")
    let fm = FileManager.default
    guard let enumerator = fm.enumerator(at: cliDir, includingPropertiesForKeys: nil) else {
        Issue.record("CLI directory not found at \(cliDir.path)")
        return
    }
    var offending: [String] = []
    while let url = enumerator.nextObject() as? URL {
        guard url.pathExtension == "swift" else { continue }
        let contents = (try? String(contentsOf: url)) ?? ""
        for line in contents.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("import AVFoundation") || trimmed.hasPrefix("import CityAudio") {
                offending.append("\(url.lastPathComponent): \(trimmed)")
            }
        }
    }
    #expect(offending.isEmpty, "CLI must not import audio frameworks; found: \(offending)")

    // project.yml level: the citybuilder-cli target's dependencies list
    // must NOT include `CityAudio`.
    let projectYML = try String(contentsOf: repoRoot().appendingPathComponent("project.yml"), encoding: .utf8)
    let cliBlock = sliceBlock(of: projectYML, startingFrom: "citybuilder-cli:")
    #expect(!cliBlock.contains("- package: CityAudio"), "project.yml citybuilder-cli must not depend on CityAudio")
}

@Test("scenario: app targets link audio")
func scenarioAppTargetsLinkAudio() throws {
    let projectYML = try String(contentsOf: repoRoot().appendingPathComponent("project.yml"), encoding: .utf8)
    let iosBlock = sliceBlock(of: projectYML, startingFrom: "CitybuilderiOS:")
    let macBlock = sliceBlock(of: projectYML, startingFrom: "CitybuilderMac:")
    #expect(iosBlock.contains("- package: CityAudio"), "CitybuilderiOS must depend on CityAudio")
    #expect(macBlock.contains("- package: CityAudio"), "CitybuilderMac must depend on CityAudio")
}

/// Returns the substring from the line containing `header` up to the next
/// top-level target / package header (lines starting with two spaces + word
/// + colon in the project.yml convention). Crude but sufficient for the
/// dependency-presence assertions above.
private func sliceBlock(of yaml: String, startingFrom header: String) -> String {
    guard let startRange = yaml.range(of: header) else { return "" }
    let rest = yaml[startRange.lowerBound...]
    let lines = rest.components(separatedBy: .newlines)
    var collected: [String] = []
    var seenHeader = false
    for line in lines {
        if !seenHeader {
            collected.append(line)
            seenHeader = true
            continue
        }
        // Stop on the next sibling target/package header — exactly two
        // spaces of indent followed by a word and a colon.
        let firstNonSpace = line.firstIndex(where: { !$0.isWhitespace })
        let isTopLevelHeader = firstNonSpace.map {
            line.distance(from: line.startIndex, to: $0) == 2 && line.hasSuffix(":")
        } ?? false
        if isTopLevelHeader { break }
        collected.append(line)
    }
    return collected.joined(separator: "\n")
}
