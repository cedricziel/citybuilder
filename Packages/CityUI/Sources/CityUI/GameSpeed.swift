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
