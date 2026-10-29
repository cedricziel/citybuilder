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
    @State private var entered = false

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
        ZStack {
            TitleBackdrop(
                active: !viewModel.presentingNewGameDialog && !viewModel.presentingSettings && viewModel.chapterSelect == nil
            )
            scrim
            menu
                // The menu sits on a dark scrim in either appearance.
                .environment(\.colorScheme, .dark)
        }
        .onAppear { entered = true }
        #if os(tvOS)
        // tvOS sheets are translucent; hide the title behind them.
        .opacity(viewModel.presentingNewGameDialog || viewModel.presentingSettings || viewModel.chapterSelect != nil ? 0 : 1)
        #endif
        // Continue and New Game are disabled while iCloud is checked.
        .tvDefaultFocus($focusedButton, primaryButton, enabled: !viewModel.isPreparingCloudSaves)
        .sheet(isPresented: $viewModel.presentingNewGameDialog) {
            NewGameDialogView(
                viewModel: NewGameDialogViewModel(),
                onStart: { world in
                    viewModel.commit(world: world, isNewGame: true)
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
        .sheet(isPresented: Binding(
            get: { viewModel.chapterSelect != nil },
            set: { if !$0 { viewModel.dismissCampaigns() } }
        )) {
            if let model = viewModel.chapterSelect {
                ChapterSelectView(
                    model: model,
                    onStart: { chapter, world in
                        viewModel.startChapter(chapter, world: world, pickedCulture: chapter.culture == nil ? model.culture : nil)
                    },
                    onClose: { viewModel.dismissCampaigns() }
                )
                #if os(macOS)
                // A Mac sheet sizes to its content; give the split view room.
                .frame(minWidth: 720, minHeight: 520)
                #endif
            }
        }
        .sheet(isPresented: $viewModel.presentingSettings) {
            if let content = settingsContent {
                content().tvSheetWidth()
            }
        }
    }

    /// Darkens the top behind the title and the bottom behind the
    /// notices, leaving the island clear in the middle.
    private var scrim: some View {
        LinearGradient(
            stops: [
                .init(color: .black.opacity(0.5), location: 0),
                .init(color: .black.opacity(0.05), location: 0.4),
                .init(color: .black.opacity(0.05), location: 0.6),
                .init(color: .black.opacity(0.55), location: 1)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    private var menu: some View {
        // Title at the top, buttons in the lower third: the town shows between.
        VStack(spacing: 32) {
            Text("Citybuilder")
                .font(.system(size: 56, weight: .bold, design: .serif))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.6), radius: 8, y: 3)
                .accessibilityAddTraits(.isHeader)
                .padding(.top, 40)
                .menuEntrance(0, entered: entered)
            Spacer()
            VStack(spacing: 16) {
                if let summary = viewModel.mostRecentSave {
                    Button {
                        viewModel.continueRequested()
                    } label: {
                        VStack(spacing: 2) {
                            Text("Continue").font(.title3.bold())
                            Text(summary.displayName)
                                .font(.caption)
                                .opacity(0.8)
                        }
                        #if os(tvOS)
                        // The system style hugs the label; keep the date on one line.
                        .frame(minWidth: 280)
                        .padding(.vertical, 10)
                        #endif
                    }
                    .titleMenuButtonStyle(prominent: true)
                    .disabled(viewModel.isPreparingCloudSaves)
                    .focused($focusedButton, equals: .continueGame)
                    .accessibilityIdentifier("title.continue")
                    .menuEntrance(1, entered: entered)
                }
                Button("New Game…") {
                    viewModel.newGameRequested()
                }
                .titleMenuButtonStyle(prominent: viewModel.mostRecentSave == nil)
                .disabled(viewModel.isPreparingCloudSaves)
                .focused($focusedButton, equals: .newGame)
                .accessibilityIdentifier("title.newGame")
                .menuEntrance(2, entered: entered)

                Button("Campaigns") {
                    viewModel.campaignsRequested()
                }
                .titleMenuButtonStyle()
                .disabled(viewModel.isPreparingCloudSaves)
                .accessibilityIdentifier("title.campaigns")
                .menuEntrance(3, entered: entered)

                Button("Settings") {
                    viewModel.settingsRequested()
                }
                .titleMenuButtonStyle()
                .accessibilityIdentifier("title.settings")
                .menuEntrance(4, entered: entered)

                #if os(macOS)
                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
                .titleMenuButtonStyle()
                .accessibilityIdentifier("title.quit")
                .menuEntrance(5, entered: entered)
                #endif
            }
            .padding(.bottom, 40)
            if viewModel.isPreparingCloudSaves {
                ProgressView("Checking iCloud for saves…")
                    .foregroundStyle(.white)
                    .accessibilityIdentifier("title.preparingCloudSaves")
            }
            if let notice = viewModel.iCloudNotice {
                Label(notice, systemImage: "icloud.slash")
                    .font(.callout)
                    .foregroundStyle(.white.opacity(0.85))
                    .multilineTextAlignment(.center)
                    .accessibilityIdentifier("title.iCloudNotice")
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
