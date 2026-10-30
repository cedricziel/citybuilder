import Foundation
import L10nCheckCore

// Usage: l10n-check [repository root, default: the current directory].
// Spec: `localization` / A completeness check guards the catalogs.
let root = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? FileManager.default.currentDirectoryPath)
do {
    let repository = try Repository(root: root)
    let findings = L10nCheck.run(catalogs: repository.catalogs, sources: repository.sources, glossary: repository.glossary)
    let keys = repository.catalogs.map(\.entries.count).reduce(0, +)
    guard findings.isEmpty else {
        findings.forEach { print($0) }
        print("l10n-check: \(findings.count) problem(s) in \(keys) keys")
        exit(1)
    }
    print("l10n-check: \(keys) keys in \(repository.catalogs.count) catalog(s), all complete")
} catch {
    print("l10n-check: \(error)")
    exit(1)
}
