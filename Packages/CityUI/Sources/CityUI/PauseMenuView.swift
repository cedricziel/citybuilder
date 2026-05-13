import CityCore
import SwiftUI

/// Modal pause menu presented as a sheet over `CityRootView` when
/// `session.isPaused == true`. Spec: `add-game-pause-menu` /
/// `pause-menu` Requirement: Modal pause menu over the running game.
public struct PauseMenuView: View {
    @Bindable public var viewModel: PauseMenuViewModel
    private let statusClearAfter: TimeInterval

    public init(viewModel: PauseMenuViewModel, statusClearAfter: TimeInterval = 2.0) {
        self.viewModel = viewModel
        self.statusClearAfter = statusClearAfter
    }

    public var body: some View {
        VStack(spacing: 12) {
            Text("Game Paused")
                .font(.title2)
                .fontWeight(.semibold)
                .padding(.top, 24)

            VStack(spacing: 8) {
                ForEach(viewModel.actions) { action in
                    actionButton(action)
                }
            }
            .padding(.horizontal, 24)

            if let message = viewModel.statusMessage {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 8)
                    .task(id: message) {
                        try? await Task.sleep(nanoseconds: UInt64(statusClearAfter * 1_000_000_000))
                        await MainActor.run {
                            if viewModel.statusMessage == message {
                                viewModel.clearStatus()
                            }
                        }
                    }
            }
            Spacer(minLength: 0)
        }
        .frame(minWidth: 320, minHeight: 320)
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private func actionButton(_ action: PauseMenuAction) -> some View {
        let button = Button {
            viewModel.invoke(action.kind)
        } label: {
            HStack(spacing: 10) {
                Image(systemName: action.systemImage)
                    .frame(width: 20)
                Text(action.label)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color.secondary.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        if action.kind == .resume {
            button
                .keyboardShortcut(.escape, modifiers: [])
                .keyboardShortcut(".", modifiers: .command)
        } else {
            button
        }
    }
}
