import CityCore
import Foundation

/// Platform the pause menu is rendering on. Injected by the app shell
/// so the headless view-model can drop the Mac-only Quit row on iOS
/// without leaning on `#if os` at the test boundary.
public enum PauseMenuPlatform: Sendable {
    case mac
    case iOS
}

/// SF Symbol name shown on the HUD pause button for the given pause
/// state. Lifted to a free function so the visual rule is testable
/// without driving SwiftUI. Spec `add-game-pause-menu` /
/// `rendering-2_5d` Requirement: HUD pause button.
public func pauseButtonSymbolName(isPaused: Bool) -> String {
    isPaused ? "play.fill" : "pause.fill"
}

/// Shell-side configuration for the pause menu. `CityRootView` owns
/// the Settings closure (it flips its own `settingsPresented` flag);
/// the rest of the actions are injected here.
public struct PauseMenuConfig {
    public let platform: PauseMenuPlatform
    public let onSaveGame: () throws -> Void
    public let onQuitToTitle: (() -> Void)?
    public let onQuit: (() -> Void)?

    public init(
        platform: PauseMenuPlatform,
        onSaveGame: @escaping () throws -> Void,
        onQuitToTitle: (() -> Void)? = nil,
        onQuit: (() -> Void)? = nil
    ) {
        self.platform = platform
        self.onSaveGame = onSaveGame
        self.onQuitToTitle = onQuitToTitle
        self.onQuit = onQuit
    }
}

/// Action shapes the pause menu can present. The `kind` discriminator
/// is what views key off; the closure inside the action is what the
/// view invokes on tap. Spec: `add-game-pause-menu` / `pause-menu`
/// Requirement: Modal pause menu over the running game.
public struct PauseMenuAction: Identifiable, Sendable {
    public enum Kind: String, Sendable {
        case resume
        case saveGame
        case settings
        case quitToTitle
        case quit
    }

    public let kind: Kind
    public let label: String
    public let systemImage: String
    public let role: ButtonRole?

    public var id: String {
        kind.rawValue
    }

    public init(kind: Kind, label: String, systemImage: String, role: ButtonRole? = nil) {
        self.kind = kind
        self.label = label
        self.systemImage = systemImage
        self.role = role
    }
}

/// Mirror of SwiftUI's button-role concept that avoids importing
/// SwiftUI into the view-model file (keeps the file usable by tests
/// that don't link SwiftUI).
public enum ButtonRole: Sendable {
    case cancel
    case destructive
}

/// View-model for the pause menu. Owns the action list (platform-
/// filtered), the per-action callbacks, and the transient
/// status-message used to surface Save Game success/failure.
@MainActor
@Observable
public final class PauseMenuViewModel {
    public let session: GameSession
    public private(set) var statusMessage: String?
    /// True while the Quit row's save-or-discard prompt is showing.
    public var isConfirmingQuit = false

    private let platform: PauseMenuPlatform
    private let onSaveGame: () throws -> Void
    private let onSettings: () -> Void
    private let onQuitToTitle: (() -> Void)?
    private let onQuit: (() -> Void)?

    public init(
        session: GameSession,
        platform: PauseMenuPlatform,
        onSaveGame: @escaping () throws -> Void,
        onSettings: @escaping () -> Void,
        onQuitToTitle: (() -> Void)?,
        onQuit: (() -> Void)?
    ) {
        self.session = session
        self.platform = platform
        self.onSaveGame = onSaveGame
        self.onSettings = onSettings
        self.onQuitToTitle = onQuitToTitle
        self.onQuit = onQuit
    }

    /// Ordered list of actions to render. Resume / Save Game /
    /// Settings always present; Quit to Title only when its callback
    /// is wired; Quit only on Mac.
    public var actions: [PauseMenuAction] {
        var result: [PauseMenuAction] = [
            PauseMenuAction(kind: .resume, label: "Resume", systemImage: "play.fill"),
            PauseMenuAction(kind: .saveGame, label: "Save Game", systemImage: "tray.and.arrow.down"),
            PauseMenuAction(kind: .settings, label: "Settings", systemImage: "gear")
        ]
        if onQuitToTitle != nil {
            result.append(
                PauseMenuAction(kind: .quitToTitle, label: "Quit to Title", systemImage: "house")
            )
        }
        if platform == .mac, onQuit != nil {
            result.append(
                PauseMenuAction(
                    kind: .quit, label: "Quit",
                    systemImage: "power", role: .destructive
                )
            )
        }
        return result
    }

    /// View-layer hook to dismiss the transient `statusMessage` after
    /// its 2-second window expires.
    public func clearStatus() {
        statusMessage = nil
    }

    /// Invoke an action kind. The view binds this to the row's tap
    /// handler; tests call it directly to assert wiring.
    public func invoke(_ kind: PauseMenuAction.Kind) {
        switch kind {
        case .resume:
            session.isPaused = false
        case .saveGame:
            do {
                try onSaveGame()
                statusMessage = "Saved"
            } catch {
                statusMessage = "Couldn't save: \(error)"
            }
        case .settings:
            onSettings()
        case .quitToTitle:
            // Best-effort silent auto-save first; failures are logged
            // but never block the title transition. Spec D7.
            try? onSaveGame()
            onQuitToTitle?()
        case .quit:
            isConfirmingQuit = true
        }
    }

    /// Answer the Quit prompt. A failed save keeps the game open and
    /// reports the error, so the player never loses progress silently.
    public func confirmQuit(saving: Bool) {
        isConfirmingQuit = false
        if saving {
            do {
                try onSaveGame()
            } catch {
                statusMessage = "Couldn't save: \(error)"
                return
            }
        }
        onQuit?()
    }
}
