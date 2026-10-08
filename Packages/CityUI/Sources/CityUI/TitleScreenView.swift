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
                    .accessibilityIdentifier("title.continue")
                }
                Button("New Game…") {
                    viewModel.newGameRequested()
                }
                .frame(maxWidth: 280)
                .padding(.vertical, 8)
                .buttonStyle(.bordered)
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
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
        .sheet(isPresented: $viewModel.presentingSettings) {
            if let content = settingsContent {
                content()
            }
        }
    }
}
