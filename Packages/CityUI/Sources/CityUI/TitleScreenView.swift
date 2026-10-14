import CityCore
import SwiftUI
#if os(macOS)
import AppKit
#endif

/// Title screen shown at app launch. Owns the pre-simulation flow:
/// Continue, New Game…, Settings, and (macOS) Quit. Once the player
/// commits a world, the view-model exposes a `GameSession` and the
/// hosting app shell replaces the title screen with `CityRootView`.
/// Spec: `add-title-screen-and-new-game` / `title-screen`.
public struct TitleScreenView: View {
    @Bindable private var viewModel: TitleScreenViewModel
    private let settingsContent: (() -> AnyView)?
    @FocusState private var focusedButton: TitleButton?

    private enum TitleButton: Hashable {
        case continueGame, newGame
    }

    public init(
        viewModel: TitleScreenViewModel,
        @ViewBuilder settings: @escaping () -> some View
    ) {
        self.viewModel = viewModel
        self.settingsContent = { AnyView(settings()) }
    }

    public init(viewModel: TitleScreenViewModel) {
        self.viewModel = viewModel
        self.settingsContent = nil
    }

    private var primaryButton: TitleButton {
        viewModel.mostRecentSave == nil ? .newGame : .continueGame
    }

    public var body: some View {
        VStack(spacing: 32) {
            Spacer()
            Text("Citybuilder")
                .font(.system(size: 56, weight: .bold, design: .serif))
                .accessibilityAddTraits(.isHeader)
            VStack(spacing: 16) {
                if let summary = viewModel.mostRecentSave {
                    Button {
                        viewModel.continueRequested()
                    } label: {
                        VStack(spacing: 2) {
                            Text("Continue").font(.title3.bold())
                            Text(summary.displayName)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: 280)
                        .padding(.vertical, 10)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(viewModel.isPreparingCloudSaves)
                    .focused($focusedButton, equals: .continueGame)
                    .accessibilityIdentifier("title.continue")
                }
                Button("New Game…") {
                    viewModel.newGameRequested()
                }
                .frame(maxWidth: 280)
                .padding(.vertical, 8)
                .buttonStyle(.bordered)
                .disabled(viewModel.isPreparingCloudSaves)
                .focused($focusedButton, equals: .newGame)
                .accessibilityIdentifier("title.newGame")

                Button("Settings") {
                    viewModel.settingsRequested()
                }
                .frame(maxWidth: 280)
                .padding(.vertical, 8)
                .buttonStyle(.bordered)
                .accessibilityIdentifier("title.settings")

                #if os(macOS)
                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
                .frame(maxWidth: 280)
                .padding(.vertical, 8)
                .buttonStyle(.bordered)
                .accessibilityIdentifier("title.quit")
                #endif
            }
            Spacer()
            if viewModel.isPreparingCloudSaves {
                ProgressView("Checking iCloud for saves…")
                    .accessibilityIdentifier("title.preparingCloudSaves")
            }
            if let notice = viewModel.iCloudNotice {
                Label(notice, systemImage: "icloud.slash")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .accessibilityIdentifier("title.iCloudNotice")
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // Continue and New Game are disabled while iCloud is checked.
        .tvDefaultFocus($focusedButton, primaryButton, enabled: !viewModel.isPreparingCloudSaves)
        .sheet(isPresented: $viewModel.presentingNewGameDialog) {
            NewGameDialogView(
                viewModel: NewGameDialogViewModel(),
                onStart: { world in
                    viewModel.commit(world: world)
                },
                onCancel: {
                    viewModel.presentingNewGameDialog = false
                }
            )
        }
        .alert(
            SaveLoadFailure.title,
            isPresented: Binding(
                get: { viewModel.loadFailure != nil },
                set: { if !$0 { viewModel.dismissLoadFailure() } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("The file may be damaged or from an older version of the game. You can still start a new game.")
        }
        .alert(
            "A newer save is in iCloud",
            isPresented: Binding(
                get: { !viewModel.saveConflicts.isEmpty && !viewModel.isResolvingSaveConflict },
                set: { _ in }
            )
        ) {
            Button("Load iCloud Save") {
                Task { await viewModel.resolveSaveConflict(keepICloud: true) }
            }
            Button("Keep This Save") {
                Task { await viewModel.resolveSaveConflict(keepICloud: false) }
            }
        } message: {
            Text((viewModel.saveConflictFailure.map { $0 + "\n\n" } ?? "")
                + "Load the newer save from iCloud, or keep the save on this device and replace the iCloud copy.")
        }
        .sheet(isPresented: $viewModel.presentingSettings) {
            if let content = settingsContent {
                content()
            }
        }
    }
}
