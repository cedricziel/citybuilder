import Foundation
import Testing
@testable import L10nCheckCore

/// Spec: `localization` / A completeness check guards the catalogs.
struct CheckRuleTests {
    @Test("scenario: a missing german value fails the check")
    func missingGerman() throws {
        let findings = try check(["pause.resume": .init(en: "Resume", de: nil)])
        #expect(findings.map(\.key) == ["pause.resume"])
        #expect(findings.first?.message.contains("no German") == true)
    }

    @Test("scenario: a german value needing review fails the check")
    func needsReview() throws {
        let findings = try check(["pause.resume": .init(en: "Resume", de: "Weiter", state: "needs_review")])
        #expect(findings.map(\.key) == ["pause.resume"])
        #expect(findings.first?.message.contains("needs_review") == true)
    }

    @Test("scenario: a placeholder mismatch fails the check")
    func placeholderMismatch() throws {
        let findings = try check(["fever.end": .init(en: "%lld left before {date}.", de: "%lld sind fort.")])
        #expect(findings.map(\.key) == ["fever.end"])
        #expect(findings.first?.message.contains("{date}") == true)
    }

    @Test("a German value may reorder positional specifiers")
    func positionalReorder() throws {
        let findings = try check(["rival.age": .init(en: "%1$@ enters the %2$@", de: "%2$@: %1$@ zieht nach")])
        #expect(findings.isEmpty)
    }

    @Test("an extra German placeholder fails the check")
    func extraPlaceholder() throws {
        let findings = try check(["saved": .init(en: "Saved", de: "Gespeichert: %@")])
        #expect(findings.map(\.key) == ["saved"])
    }

    @Test("plural forms compare against the English forms")
    func pluralForms() throws {
        let entry = Entry(
            en: .plural(["one": "%lld building", "other": "%lld buildings"]),
            de: .plural(["one": "%lld Gebäude", "other": "%lld Gebäude"])
        )
        #expect(try check(["count.building": entry]).isEmpty)
        let broken = Entry(
            en: .plural(["one": "%lld building", "other": "%lld buildings"]),
            de: .plural(["one": "ein Gebäude", "other": "viele Gebäude"])
        )
        #expect(try check(["count.building": broken]).map(\.message).count == 2)
    }

    @Test("scenario: an unknown key in code fails the check")
    func unknownKey() throws {
        let source = SourceFile(path: "Packages/CityUI/Sources/CityUI/X.swift", text: """
        let a = GameText.string("pause.resume")
        let b = Text(l10n: "pause.resmue")
        """)
        let findings = try check(["pause.resume": .init(en: "Resume", de: "Weiter")], sources: [source])
        #expect(findings.map(\.key) == ["pause.resmue"])
        #expect(findings.first?.location == "Packages/CityUI/Sources/CityUI/X.swift:2")
    }

    @Test("scenario: an article before a noun placeholder fails the check")
    func articleBeforePlaceholder() throws {
        let findings = try check([
            "fire.ignition": .init(en: "A {building} is burning.", de: "Eine {building} brennt."),
            "fire.short": .init(en: "Fire: %@", de: "Brand in der %@")
        ])
        #expect(findings.map(\.key).sorted() == ["fire.ignition", "fire.short"])
    }

    @Test("scenario: an avoided glossary word fails the check")
    func avoidedWord() throws {
        let findings = try check(["orders.title": .init(en: "Orders", de: "Bestellung")])
        #expect(findings.map(\.key) == ["orders.title"])
        #expect(findings.first?.message.contains("Auftrag") == true)
    }

    @Test("avoided words match whole words only")
    func avoidedWholeWord() throws {
        #expect(try check(["orders.title": .init(en: "Orders", de: "Bestellungsbuch")]).isEmpty)
    }

    @Test("scenario: formal address fails the check")
    func formalAddress() throws {
        let findings = try check(["hint": .init(en: "You can build here.", de: "Hier Sie können bauen.")])
        #expect(findings.map(\.key) == ["hint"])
    }

    @Test("scenario: complete catalogs pass the check")
    func completePasses() throws {
        let source = SourceFile(path: "X.swift", text: #"Text(l10n: "pause.resume")"#)
        let findings = try check(
            ["pause.resume": .init(en: "Resume", de: "Weiter"), "pause.saved": .init(en: "Saved", de: "Gespeichert")],
            sources: [source]
        )
        #expect(findings.isEmpty)
    }

    @Test("a key marked not to translate needs no German")
    func doNotTranslate() throws {
        #expect(try check(["brand": .init(en: "Citybuilder", de: nil, shouldTranslate: false)]).isEmpty)
    }
}
