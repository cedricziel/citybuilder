#!/usr/bin/env swift
// scripts/check-scenario-coverage.swift
//
// Scans openspec/changes/*/specs/**/*.md and openspec/specs/**/*.md for
// `#### Scenario:` headers and maps each to an expected swift-testing test
// name. Reports which scenarios have not yet been covered by a test.
//
// Mapping convention (design D13): a `#### Scenario: Foo bar baz` header
// is considered covered when at least one Swift source file under
// Packages/*/Tests/**/*.swift contains the literal string
// `@Test("scenario: foo bar baz")` (case-insensitive on the title).
//
// Exit codes:
//   0 — every scenario has a matching test
//   1 — at least one scenario is unmapped (or the script itself errored)
//
// During the early-M0 / M1 phase this script may report many unmapped
// scenarios — that is expected and informational. Once M11 task 11.4 is
// reached the absence of mappings becomes a hard failure.

import Foundation

let fileManager = FileManager.default
let repoRoot = FileManager.default.currentDirectoryPath

func mdFiles(under directories: [String]) -> [URL] {
    var found: [URL] = []
    for dir in directories {
        let root = URL(fileURLWithPath: dir)
        guard
            let enumerator = fileManager.enumerator(
                at: root,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            )
        else { continue }
        for case let url as URL in enumerator where url.pathExtension == "md" {
            found.append(url)
        }
    }
    return found
}

func swiftFiles(under directory: String) -> [URL] {
    var found: [URL] = []
    let root = URL(fileURLWithPath: directory)
    guard
        let enumerator = fileManager.enumerator(
            at: root,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )
    else { return [] }
    for case let url as URL in enumerator where url.pathExtension == "swift" {
        if url.path.contains("/Tests/") { found.append(url) }
    }
    return found
}

struct Scenario {
    let title: String
    let specFile: String
    let lineNumber: Int

    var expectedTestNeedle: String {
        "@Test(\"scenario: \(title.lowercased())\")"
    }
}

func extractScenarios(from urls: [URL]) -> [Scenario] {
    var scenarios: [Scenario] = []
    for url in urls {
        guard let body = try? String(contentsOf: url, encoding: .utf8) else { continue }
        let lines = body.split(separator: "\n", omittingEmptySubsequences: false)
        for (index, raw) in lines.enumerated() {
            let line = String(raw)
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            // Require exactly 4 hashtags (`#### Scenario:`). Three hashtags
            // is a Requirement; five+ is unusual.
            guard trimmed.hasPrefix("#### Scenario:") else { continue }
            let title = trimmed
                .replacingOccurrences(of: "#### Scenario:", with: "")
                .trimmingCharacters(in: .whitespaces)
            guard !title.isEmpty else { continue }
            scenarios.append(
                Scenario(title: title, specFile: url.path, lineNumber: index + 1)
            )
        }
    }
    return scenarios
}

func loadTestCorpus(from urls: [URL]) -> String {
    var combined = ""
    for url in urls {
        if let body = try? String(contentsOf: url, encoding: .utf8) {
            combined.append(body.lowercased())
            combined.append("\n")
        }
    }
    return combined
}

// ----- main -----------------------------------------------------------

let specRoots = [
    "\(repoRoot)/openspec/changes",
    "\(repoRoot)/openspec/specs"
]
let testRoot = "\(repoRoot)/Packages"

let specMarkdowns = mdFiles(under: specRoots)
let testSwifts = swiftFiles(under: testRoot)
let testCorpus = loadTestCorpus(from: testSwifts)

let scenarios = extractScenarios(from: specMarkdowns)

var unmapped: [Scenario] = []
for scenario in scenarios where !testCorpus.contains(scenario.expectedTestNeedle.lowercased()) {
    unmapped.append(scenario)
}

print("scenario coverage: \(scenarios.count - unmapped.count)/\(scenarios.count) scenarios mapped")

if !unmapped.isEmpty {
    print("")
    print("Unmapped scenarios (no @Test with matching title found):")
    for scenario in unmapped {
        let relativePath = scenario.specFile.replacingOccurrences(of: repoRoot + "/", with: "")
        print("  \(relativePath):\(scenario.lineNumber)  #### Scenario: \(scenario.title)")
        print("    expect: \(scenario.expectedTestNeedle)")
    }
    print("")

    // M0/M1: report only. M11 task 11.4: become a hard gate.
    if ProcessInfo.processInfo.environment["SCENARIO_COVERAGE_STRICT"] == "1" {
        print("SCENARIO_COVERAGE_STRICT=1 set — failing.")
        exit(1)
    }
    print("(strict mode off — reporting only. Set SCENARIO_COVERAGE_STRICT=1 to fail.)")
    exit(0)
}

exit(0)
