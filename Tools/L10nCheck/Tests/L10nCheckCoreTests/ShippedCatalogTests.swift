import Foundation
import Testing
@testable import L10nCheckCore

/// Spec: `localization` / German text follows the glossary and tone guide.
/// These read the repository's own catalogs and glossary.
struct ShippedCatalogTests {
    static let root = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .deletingLastPathComponent().deletingLastPathComponent()

    static let repository = Result { try Repository(root: root) }

    static func findings() throws -> [Finding] {
        let repository = try repository.get()
        #expect(!repository.catalogs.isEmpty)
        return L10nCheck.run(catalogs: repository.catalogs, sources: repository.sources, glossary: repository.glossary)
    }

    @Test("scenario: german text uses the glossary words")
    func glossaryWords() throws {
        #expect(try Self.findings().filter { $0.message.contains("the glossary says") } == [])
    }

    @Test("scenario: german text addresses the player with du")
    func duForm() throws {
        #expect(try Self.findings().filter { $0.message.contains("formal address") } == [])
    }

    @Test("the repository passes the whole check")
    func repositoryPasses() throws {
        #expect(try Self.findings() == [])
    }

    @Test("the glossary file names every avoided word once")
    func glossaryHasNoDuplicates() throws {
        let words = try Self.repository.get().glossary.terms.flatMap(\.avoid)
        #expect(Set(words).count == words.count)
    }
}
