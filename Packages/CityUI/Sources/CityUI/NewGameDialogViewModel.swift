import CityCore
import Foundation

/// View-model behind `NewGameDialogView`. Owns the player's layout +
/// seed selection and produces a freshly-constructed `World` on commit.
/// Spec: `add-title-screen-and-new-game` / `title-screen`.
@MainActor
@Observable
public final class NewGameDialogViewModel {
    /// Seed-entry mode. `.random` carries the captured value so the
    /// player sees the same number they're about to play with — tapping
    /// Start must NOT re-roll.
    public enum SeedMode: Equatable {
        case `default`
        case random(captured: UInt64)
        case custom(text: String)
    }

    public var layout: WorldLayout
    public var seedMode: SeedMode
    /// Spec: `platform-shells` / New Game offers a culture.
    public var culture: Culture
    /// Spec: `platform-shells` / New Game offers a starting age.
    public var age: Age
    /// Spec: `platform-shells` / New Game offers difficulty and scenarios.
    public enum Mode: Hashable, Sendable { case sandbox, scenario }
    public var mode: Mode = .sandbox
    public var difficulty: Difficulty = .normal
    public var scenario: Scenario = .firstHarvest

    public init(
        layout: WorldLayout = .singleIsland,
        seedMode: SeedMode = .default,
        culture: Culture = .northernEuropean,
        age: Age = .medieval
    ) {
        self.layout = layout
        self.seedMode = seedMode
        self.culture = culture
        self.age = age
    }

    /// Roll a new random seed and capture it into `.random(captured:)`.
    /// Subsequent reads of `seedMode` see the same value until the next
    /// call.
    public func useRandomSeed() {
        var rng = SystemRandomNumberGenerator()
        seedMode = .random(captured: rng.next())
    }

    /// `Start` is enabled only when the current selection produces a
    /// parsable seed. Custom mode with non-numeric input is rejected.
    public var isStartEnabled: Bool {
        resolvedSeed != nil
    }

    /// Build a fresh world from the current selection, or nil when
    /// validation fails (custom seed with non-numeric text).
    public func commit() -> World? {
        guard let seed = resolvedSeed else { return nil }
        switch mode {
        case .sandbox:
            return World.newGame(layout: layout, seed: seed, culture: culture, age: age, difficulty: difficulty)
        case .scenario:
            return World.newGame(layout: layout, seed: seed, culture: culture, scenario: scenario)
        }
    }

    /// Reset selection to defaults — invoked when the dialog is
    /// cancelled so the next presentation starts clean.
    public func cancel() {
        layout = .singleIsland
        seedMode = .default
        culture = .northernEuropean
        age = .medieval
        mode = .sandbox
        difficulty = .normal
        scenario = .firstHarvest
    }

    private var resolvedSeed: UInt64? {
        switch seedMode {
        case .default:
            return 0
        case let .random(captured):
            return captured
        case let .custom(text):
            return UInt64(text.trimmingCharacters(in: .whitespaces))
        }
    }
}
