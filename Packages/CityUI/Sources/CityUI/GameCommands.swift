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
        case .togglePause: if isPaused { GameText.string("pause.resume") } else { GameText.string("commands.pause") }
        case let .speed(speed): GameText.string("commands.speed", speed.label)
        case .zoomIn: GameText.string("commands.zoomIn")
        case .zoomOut: GameText.string("commands.zoomOut")
        }
    }

    /// Space would reach the open sheet's buttons, so Pause waits until
    /// the sheet closes.
    public func isEnabled(hasSession: Bool, hasSheet: Bool) -> Bool {
        hasSession && !(self == .togglePause && hasSheet)
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

struct GameHasSheetFocusKey: FocusedValueKey {
    typealias Value = Bool
}

extension FocusedValues {
    /// The open game, published by `CityRootView` for the Game menu.
    var gameSession: GameSession? {
        get { self[GameSessionFocusKey.self] }
        set { self[GameSessionFocusKey.self] = newValue }
    }

    /// Whether the open game shows a sheet.
    var gameHasSheet: Bool? {
        get { self[GameHasSheetFocusKey.self] }
        set { self[GameHasSheetFocusKey.self] = newValue }
    }
}

/// The Game menu; the Mac app adds it to its scene's commands. Its items
/// are disabled while no game is open.
public struct GameCommands: Commands {
    @FocusedValue(\.gameSession) private var session
    @FocusedValue(\.gameHasSheet) private var hasSheet

    public init() {}

    public var body: some Commands {
        CommandMenu(GameText.string("mac.gameMenu")) {
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
        .disabled(!command.isEnabled(hasSession: session != nil, hasSheet: hasSheet ?? false))
    }
}
#endif
