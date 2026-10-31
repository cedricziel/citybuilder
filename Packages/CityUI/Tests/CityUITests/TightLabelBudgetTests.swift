import CityCore
import CoreText
import Foundation
import Testing
@testable import CityUI
#if canImport(AppKit)
import AppKit

private typealias PlatformFont = NSFont
#else
import UIKit

private typealias PlatformFont = UIFont
#endif

/// Spec: `localization` / A pseudo-locale exposes long and bypassed strings
/// ("Tight labels fit in German", "Tight labels fit in the pseudo-locale");
/// design D11 of `add-localization`. Each label is measured with CoreText at
/// the font the HUD draws it in. Text styles use their iOS sizes at the
/// default type size (the HUD clamps Dynamic Type). Widths are the narrowest
/// device the label shows on: a 375-point phone in portrait unless the entry
/// says otherwise. Apple TV's orders entry has no label (#305).
struct TightLabelBudgetTests {
    struct Font: Sendable {
        let size: CGFloat
        fileprivate var weight = PlatformFont.Weight.regular
        var isMonospaced = false

        static let caption = Font(size: 12, weight: .semibold)
        static let caption2 = Font(size: 11)
        static let subheadline = Font(size: 15, weight: .semibold)
        static let body = Font(size: 17)
        static let title2 = Font(size: 22, weight: .semibold)

        fileprivate var platformFont: PlatformFont {
            isMonospaced
                ? .monospacedSystemFont(ofSize: size, weight: weight)
                : .systemFont(ofSize: size, weight: weight)
        }
    }

    struct TightLabel: Sendable, CustomTestStringConvertible {
        let name: String
        let font: Font
        /// The points the text has: the view's width less its padding,
        /// glyphs and neighbours.
        let width: CGFloat
        /// The view's `minimumScaleFactor`; 1 where the text never shrinks.
        var minimumScale: CGFloat = 1
        /// The issue tracking the label's pseudo overflow. German has no such escape.
        var pseudoIssue: Int?
        let texts: @Sendable (Language) -> [String]

        var testDescription: String {
            name
        }
    }

    /// The phone the HUD is narrowest on, less the HUD's margins of 8.
    static let phoneHUDWidth: CGFloat = 375 - 2 * 8

    /// The strip's sprite (32), cancel button (36), two gaps of 10 and its padding (10 and 6).
    static let toolStripWidth = phoneHUDWidth - 104

    /// The tool strip title's " · $cost", drawn monospaced after the name.
    static let costSuffixWidth = width(
        of: " · $\(BuildPalette.kinds.map { BuildingCatalog.spec(for: $0).cost }.max() ?? 0)",
        in: Font(size: 15, weight: .medium, isMonospaced: true).platformFont
    )

    static func strings(_ keys: String..., in language: Language) -> [String] {
        keys.map { GameText.string($0, in: language) }
    }

    static let labels: [TightLabel] = [
        // A dock item is 64 points on a phone; the iPad rail is 76 less its padding of 4.
        TightLabel(name: "build rail item", font: Font(size: 11, weight: .medium), width: 64, minimumScale: 0.7) { language in
            strings("build.category.town", "build.category.gather", "build.category.craft", "build.road", "tool.demolish", in: language)
        },
        // A phone's tile is 78 points less 4 a side; a locked tile also shows its lock (9-point glyph, 3 spacing).
        TightLabel(
            name: "build drawer tile", font: Font(size: 11, weight: .semibold), width: 78 - 8 - 12, minimumScale: 0.7, pseudoIssue: 365
        ) { language in
            BuildPalette.kinds.map { GameText.string($0.nameKey, in: language) }
        },
        TightLabel(name: "tool strip title", font: .subheadline, width: toolStripWidth - costSuffixWidth) { language in
            BuildPalette.kinds.map { GameText.string($0.nameKey, in: language) } + strings("tool.demolish", in: language)
        },
        // The hint with a hut's in-reach count appended truncates in English too (#366).
        TightLabel(name: "tool strip hint", font: .caption2, width: toolStripWidth, pseudoIssue: 365) { language in
            let road = GameText.inSentence(GameText.string(BuildingKind.road.nameKey, in: language), in: language)
            return strings("tool.demolishHint.tap", "tool.positionPlace", in: language)
                + [GameText.string("tool.dragPlace.tap", road, in: language)]
        },
        // The sheet is at least 320 wide; a row pads 24 outside and 12 inside, its icon takes 20 and a gap of 10.
        TightLabel(name: "pause menu action", font: .body, width: 320 - 48 - 24 - 30) { language in
            strings("pause.resume", "pause.saveGame", "common.settings", "pause.quitToTitle", "common.quit", in: language)
        },
        TightLabel(name: "pause menu title", font: .title2, width: 320) { language in
            strings("pause.title", in: language)
        },
        // Beside the first-steps capsule; the chip pads 10 a side around a 12-point glyph and a gap of 5.
        TightLabel(
            name: "date chip",
            font: .caption,
            width: phoneHUDWidth - DateChipLayout.firstStepsWidth - DateChipLayout.gap - 37,
            minimumScale: 0.7,
            pseudoIssue: 365
        ) { language in
            Age.allCases.flatMap { age in
                Season.allCases.flatMap { season in
                    [age.startYear, age.startYear + 99].map { GameText.date(GameDate(year: $0, season: season), in: language) }
                }
            }
        },
        // Beside the first-steps card the chip drops to its glyph where the words don't fit (#364); once
        // the card is gone the words must fit the HUD, less the glyph (18), a gap of 6 and padding of 4 and 10.
        TightLabel(name: "event chip", font: .caption, width: phoneHUDWidth - 38) { language in
            Season.allCases.flatMap { season in
                let name = GameText.string(season.nameKey, in: language)
                return ["chip.fireRisk", "chip.fireSeason", "chip.blight", "chip.fever", "chip.festival"]
                    .map { GameText.string($0, name, in: language) }
            } + [GameText.string("chip.fireBurning", 12, in: language)]
        },
        // #308. An iPad callout's footer less its padding: Details (50), a gap of 8, then the fee button.
        TightLabel(
            name: "inspector fee button",
            font: .caption,
            width: InspectorCalloutLayout.width(for: .pad) - 2 * InspectorCalloutLayout.padding.width - 50 - 8,
            pseudoIssue: 365
        ) { language in
            let fee = BuildingKind.allCases.map { World.clearingFee(of: $0) }.max() ?? 0
            let money = HUDViewModel.formatMoney(fee, locale: language.locale)
            return ["inspector.clearRuins", "inspector.pullDown"].map { GameText.string($0, money, in: language) }
        }
    ]

    @Test("scenario: tight labels fit in German", arguments: labels)
    func germanFits(_ label: TightLabel) {
        Self.expectFits(label, in: .de)
    }

    @Test("scenario: tight labels fit in the pseudo-locale", arguments: labels)
    func pseudoFits(_ label: TightLabel) {
        Self.expectFits(label, in: .pseudo, knownIssue: label.pseudoIssue)
    }

    @Test("English fits every budget, so no budget starts out wrong", arguments: labels)
    func englishFits(_ label: TightLabel) {
        Self.expectFits(label, in: .en)
    }

    static func expectFits(_ label: TightLabel, in language: Language, knownIssue: Int? = nil) {
        let font = label.font.platformFont
        let check = {
            for text in label.texts(language) {
                let needed = width(of: text, in: font) * label.minimumScale
                #expect(needed <= label.width, "\(label.name): “\(text)” needs \(Int(needed.rounded(.up))) of \(Int(label.width)) points")
            }
        }
        if let knownIssue {
            withKnownIssue("#\(knownIssue)", check)
        } else {
            check()
        }
    }

    fileprivate static func width(of text: String, in font: PlatformFont) -> CGFloat {
        let attributed = NSAttributedString(string: text, attributes: [.font: font])
        return CGFloat(CTLineGetTypographicBounds(CTLineCreateWithAttributedString(attributed), nil, nil, nil))
    }
}
