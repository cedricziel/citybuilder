import CityCore
import SwiftUI

/// Modal dialog shown when the player taps `New Game…` on the title
/// screen. Owns the layout + seed selection and hands the committed
/// world back through `onStart`. Spec: `add-title-screen-and-new-game`
/// / `title-screen` Requirement: New-game dialog.
public struct NewGameDialogView: View {
    @Bindable private var viewModel: NewGameDialogViewModel
    private let onStart: (World) -> Void
    private let onCancel: () -> Void
    @State private var customSeedText: String = ""

    public init(
        viewModel: NewGameDialogViewModel,
        onStart: @escaping (World) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.viewModel = viewModel
        self.onStart = onStart
        self.onCancel = onCancel
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("New Game")
                .font(.title.bold())

            layoutSection
            seedSection

            cultureSection

            ageSection

            HStack {
                Button("Cancel") {
                    viewModel.cancel()
                    onCancel()
                }
                .keyboardShortcut(.cancelAction)
                Spacer()
                Button("Start") {
                    if let world = viewModel.commit() {
                        onStart(world)
                    }
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(!viewModel.isStartEnabled)
                .accessibilityIdentifier("newGame.start")
            }
        }
        .padding(24)
        .frame(minWidth: 360, idealWidth: 440)
    }

    private var ageSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Starting age").font(.headline)
            Picker("Starting age", selection: $viewModel.age) {
                ForEach(Age.allCases, id: \.self) { age in
                    Text(age.displayName).tag(age)
                }
            }
            .pickerStyle(.menu)
            .accessibilityIdentifier("newGame.age")
            Text(viewModel.age.blurb)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var cultureSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Culture").font(.headline)
            Picker("Culture", selection: $viewModel.culture) {
                ForEach(Culture.allCases, id: \.self) { culture in
                    Text(culture.displayName).tag(culture)
                }
            }
            .pickerStyle(.menu)
            .accessibilityIdentifier("newGame.culture")
            Text(viewModel.culture.blurb)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var layoutSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("World layout").font(.headline)
            Picker("Layout", selection: $viewModel.layout) {
                Text("Single Island").tag(WorldLayout.singleIsland)
                Text("Archipelago").tag(WorldLayout.archipelago)
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("newGame.layout")
        }
    }

    private var seedSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Seed").font(.headline)
            Picker("Seed mode", selection: seedModeTag) {
                Text("Default").tag(SeedModeTag.default)
                Text("Random").tag(SeedModeTag.random)
                Text("Custom").tag(SeedModeTag.custom)
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("newGame.seedMode")

            seedDetail
        }
    }

    @ViewBuilder
    private var seedDetail: some View {
        switch viewModel.seedMode {
        case .default:
            Text("Seed: 0 (same world every time)")
                .font(.caption)
                .foregroundStyle(.secondary)
        case let .random(captured):
            HStack {
                Text("Seed: \(captured)")
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Re-roll") {
                    viewModel.useRandomSeed()
                }
                .buttonStyle(.borderless)
            }
        case .custom:
            TextField("Decimal seed (UInt64)", text: customSeedBinding)
                .textFieldStyle(.roundedBorder)
                .accessibilityIdentifier("newGame.customSeed")
        }
    }

    private var seedModeTag: Binding<SeedModeTag> {
        Binding(
            get: { SeedModeTag(viewModel.seedMode) },
            set: { newTag in
                switch newTag {
                case .default:
                    viewModel.seedMode = .default
                case .random:
                    viewModel.useRandomSeed()
                case .custom:
                    viewModel.seedMode = .custom(text: customSeedText)
                }
            }
        )
    }

    private var customSeedBinding: Binding<String> {
        Binding(
            get: {
                if case let .custom(text) = viewModel.seedMode { return text }
                return customSeedText
            },
            set: { new in
                customSeedText = new
                viewModel.seedMode = .custom(text: new)
            }
        )
    }
}

/// Three-state tag mirroring `NewGameDialogViewModel.SeedMode` so the
/// `Picker` can drive selection without carrying associated values.
private enum SeedModeTag: Hashable {
    case `default`
    case random
    case custom

    init(_ mode: NewGameDialogViewModel.SeedMode) {
        switch mode {
        case .default: self = .default
        case .random: self = .random
        case .custom: self = .custom
        }
    }
}
