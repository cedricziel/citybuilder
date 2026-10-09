import Foundation

/// Game speed as ticks per timer firing. Spec: `platform-shells` / Game speed.
public enum GameSpeed: Int, CaseIterable, Sendable {
    case normal = 1
    case double = 2
    case triple = 3

    public var label: String {
        "\(rawValue)×"
    }

    /// The compact idiom's single button steps 1× → 2× → 3× → 1×.
    public var next: GameSpeed {
        GameSpeed(rawValue: rawValue % 3 + 1) ?? .normal
    }
}

/// Spec: `platform-shells` / Game speed.
@MainActor
public extension GameSession {
    /// Sets the speed and resumes a paused game.
    func choose(speed: GameSpeed) {
        self.speed = speed
        isPaused = false
    }

    /// The phone's single speed button: steps the speed and resumes.
    func stepSpeed() {
        choose(speed: speed.next)
    }
}
