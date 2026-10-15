import GameDataModel
import Testing

@Test func idsWithTheSameSwiftCaseNameAreRejected() {
    let extra = """
    items:
      - { kind: Good, id: salt-1, name: Salt, unit: sacks, basePrice: 3 }
      - { kind: Good, id: salt1, name: Salt, unit: sacks, basePrice: 3 }
    """
    let errors = Fixtures.errors(Fixtures.withExtraPack(extra))
    #expect(errors.contains { $0.contains("Good salt1") && $0.contains("salt-1") && $0.contains("case") })
}

@Test func sameSwiftCaseNameInDifferentKindsIsAllowed() {
    let extra = "items:\n  - { kind: Building, id: wood, effect: code, footprint: [1, 1], cost: 1 }\n"
    #expect(Fixtures.errors(Fixtures.withExtraPack(extra)) == [])
}

private let keywords = [
    "associatedtype", "break", "catch", "continue", "defer", "deinit", "fallthrough", "fileprivate", "guard",
    "precedencegroup", "repeat", "rethrows", "subscript", "throws", "typealias", "default", "self", "in"
]

@Test func swiftKeywordIdsAreBackQuoted() throws {
    let goods = keywords.map { "  - { kind: Good, id: \"\($0)\", name: X, unit: u, basePrice: 1, neededBy: [merchants] }\n" }.joined()
    let data = try Fixtures.load(Fixtures.withExtraPack("items:\n" + goods)).get()
    let source = try #require(SwiftEmitter.emit(data)["Good+Generated.swift"])
    for keyword in keywords {
        #expect(source.contains("    case `\(keyword)`\n"), "\(keyword)")
        #expect(source.contains("case .`\(keyword)`:"), "\(keyword)")
    }
}
