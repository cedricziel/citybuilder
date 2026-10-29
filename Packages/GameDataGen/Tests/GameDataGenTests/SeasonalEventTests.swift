import GameDataModel
import Testing

// Scenarios from openspec/changes/add-event-counterplay (seasonal-events /
// Seasonal events are game data; goods-and-production / Crop fields are
// marked in the game data).

private let events = """
items:
  - kind: Event
    id: fire
    effect: fire
    seasons: [summer, autumn]
    weight: { easy: 1, normal: 1, hard: 2 }
    banners:
      warning: { title: "Dry {season} ahead", text: Fire risk is high next season. }
      ignition: { title: Fire!, text: "A {building} is burning." }
  - kind: Event
    id: festival
    effect: festival
    seasons: [spring, summer]
    minAge: medieval
    weight: { easy: 3, normal: 1, hard: 1 }
    banners:
      request: { title: The town wants a festival, text: "Deliver {bread} bread." }
"""

@Test("scenario: seasonal events load from a pack")
func seasonalEventsLoad() throws {
    let data = try Fixtures.load(Fixtures.withExtraPack(events)).get()
    #expect(data.events.map(\.id) == ["fire", "festival"])
    let fire = data.events[0]
    #expect(fire.effect == "fire" && fire.seasons == ["summer", "autumn"] && fire.minAge == nil)
    #expect(fire.weights == ["easy": 1, "normal": 1, "hard": 2])
    let warning = try #require(fire.banners.first { $0.key == "warning" })
    #expect(warning.title == "Dry {season} ahead")
    #expect(data.events[1].minAge == "medieval")
}

@Test("scenario: A spring hazard is rejected")
func springHazardIsRejected() {
    let bad = events.replacingOccurrences(of: "seasons: [summer, autumn]", with: "seasons: [spring, summer]")
    let errors = Fixtures.errors(Fixtures.withExtraPack(bad))
    #expect(errors.contains { $0.contains("Event fire") && $0.contains("spring") }, "\(errors)")
}

@Test func unknownEffectAgeAndSeasonAreRejected() {
    let bad = events
        .replacingOccurrences(of: "effect: fire", with: "effect: flood")
        .replacingOccurrences(of: "minAge: medieval", with: "minAge: stone")
        .replacingOccurrences(of: "seasons: [spring, summer]", with: "seasons: [monsoon]")
    let errors = Fixtures.errors(Fixtures.withExtraPack(bad))
    #expect(errors.contains { $0.contains("Event fire") && $0.contains("flood") }, "\(errors)")
    #expect(errors.contains { $0.contains("Event festival") && $0.contains("stone") }, "\(errors)")
    #expect(errors.contains { $0.contains("Event festival") && $0.contains("monsoon") }, "\(errors)")
}

@Test func eventWithoutSeasonsIsRejected() {
    let bad = events.replacingOccurrences(of: "seasons: [summer, autumn]", with: "seasons: []")
    let errors = Fixtures.errors(Fixtures.withExtraPack(bad))
    #expect(errors.contains { $0.contains("Event fire") && $0.contains("`seasons`") }, "\(errors)")
}

@Test func eventWeightsAreChecked() {
    let bad = events
        .replacingOccurrences(of: "{ easy: 1, normal: 1, hard: 2 }", with: "{ easy: -1, normal: 1 }")
        .replacingOccurrences(of: "title: Fire!", with: "title: \"\"")
    let errors = Fixtures.errors(Fixtures.withExtraPack(bad))
    #expect(errors.contains { $0.contains("Event fire") && $0.contains("`weight`") }, "\(errors)")
    #expect(errors.contains { $0.contains("Event fire") && $0.contains("hard") }, "\(errors)")
    #expect(errors.contains { $0.contains("Event fire") && $0.contains("title") }, "\(errors)")
}

@Test func unknownBannerIsRejected() {
    let bad = events.replacingOccurrences(of: "ignition: {", with: "thunder: {")
    let errors = Fixtures.errors(Fixtures.withExtraPack(bad))
    #expect(errors.contains { $0.contains("Event fire") && $0.contains("thunder") }, "\(errors)")
}

@Test func duplicateEventIdsAreRejected() {
    let bad = events + "\n" + events.replacingOccurrences(of: "items:\n", with: "")
    let errors = Fixtures.errors(Fixtures.withExtraPack(bad))
    #expect(errors.contains { $0.contains("duplicate Event id") }, "\(errors)")
}

@Test func emitsSeasonalEvents() throws {
    let source = try emitted("SeasonalEvent+Generated.swift", from: Fixtures.withExtraPack(events))
    #expect(source.contains("public enum SeasonalEvent: String, CaseIterable, Codable, Sendable {"))
    #expect(source.contains("case .fire: .fire\n"))
    #expect(source.contains("case .fire: [.summer, .autumn]"))
    #expect(source.contains("case .fire: .antiquity"))
    #expect(source.contains("case .festival: .medieval"))
    #expect(source.contains("case .fire: [.easy: 1, .normal: 1, .hard: 2]"))
    #expect(source.contains("case .fire: [.warning: SeasonalBanner(title: \"Dry {season} ahead\", "))
    #expect(source.contains(".ignition: SeasonalBanner(title: \"Fire!\", text: \"A {building} is burning.\")]"))
}

@Test("scenario: The sheep farm is not a crop")
func cropFlagIsEmitted() throws {
    let core = Fixtures.core.replacingOccurrences(of: "catchmentRadius: 2\n", with: "catchmentRadius: 2\n    crop: true\n")
    let source = try emitted("BuildingKind+Generated.swift", from: Fixtures.withCore(core))
    #expect(source.contains("public var isCrop: Bool {"))
    #expect(source.contains("case .lumberjackHut: true"))
    #expect(source.contains("case .sawmill: false"))
}

@Test func cropNeedsARecipe() {
    let core = Fixtures.core.replacingOccurrences(of: "storage: 8\n", with: "storage: 8\n    crop: true\n")
    let errors = Fixtures.errors(Fixtures.withCore(core))
    #expect(errors.contains { $0.contains("Building house") && $0.contains("`crop`") }, "\(errors)")
}
