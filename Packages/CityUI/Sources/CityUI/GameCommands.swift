#if os(macOS)
import SwiftUI

/// An item of the Mac's Game menu. Spec: `platform-shells` / Mac Game menu.
public enum GameMenuCommand: Hashable, CaseIterable, Sendable {
    case togglePause
    case speed(GameSpeed)
    case zoomIn, zoomOut

    /// The menu's sections, divided by separators.
    static let groups: [[GameMenuCommand]] = [[.togglePause], GameSpeed.allCases.map(speed), [.zoomIn, .zoomOut]]

    public static var allCases: [GameMenuCommand] {
        groups.flatMap(\.self)
    }

    /// Bare 1, 2 and 3 open the build drawers, so the speeds take ⌘.
    public var key: KeyEquivalent {
        switch self {
        case .togglePause: .space
        case let .speed(speed): KeyEquivalent(Character(String(speed.rawValue)))
        case .zoomIn: "+"
        case .zoomOut: "-"
        }
    }

    public var modifiers: EventModifiers {
        self == .togglePause ? [] : .command
    }

    public func title(isPaused: Bool) -> String {
        switch self {
        case .togglePause: isPaused ? "Resume" : "Pause"
        case let .speed(speed): "Speed \(speed.label)"
        case .zoomIn: "Zoom In"
        case .zoomOut: "Zoom Out"
        }
    }

    @MainActor
    public func perform(on session: GameSession) {
        switch self {
        case .togglePause: session.togglePause()
        case let .speed(speed): session.choose(speed: speed)
        case .zoomIn: session.zoomIn()
        case .zoomOut: session.zoomOut()
        }
    }
}

struct GameSessionFocusKey: FocusedValueKey {
    typealias Value = GameSession
}

extension FocusedValues {
    /// The open game, published by `CityRootView` for the Game menu.
    var gameSession: GameSession? {
        get { self[GameSessionFocusKey.self] }
        set { self[GameSessionFocusKey.self] = newValue }
    }
}

/// The Game menu; the Mac app adds it to its scene's commands. Its items
/// are disabled while no game is open.
public struct GameCommands: Commands {
    @FocusedValue(\.gameSession) private var session

    public init() {}

    public var body: some Commands {
        CommandMenu("Game") {
            ForEach(GameMenuCommand.groups.indices, id: \.self) { index in
                if index > 0 { Divider() }
                ForEach(GameMenuCommand.groups[index], id: \.self, content: item)
            }
        }
    }

    private func item(_ command: GameMenuCommand) -> some View {
        Button(command.title(isPaused: session?.isPaused ?? false)) {
            if let session { command.perform(on: session) }
        }
        .keyboardShortcut(command.key, modifiers: command.modifiers)
        .disabled(session == nil)
    }
}
#endif
