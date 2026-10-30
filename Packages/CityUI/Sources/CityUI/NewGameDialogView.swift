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
    @FocusState private var startFocused: Bool

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
        ScrollView {
            content
        }
        .tvDefaultFocus($startFocused, true)
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text(l10n: "newGame.title")
                .font(.title.bold())
            // A remote cannot reach a Start button below the long form,
            // and a TV is wide, so Apple TV shows the buttons under the
            // title and the form in two columns. As one focus section the
            // button row takes Up from either column.
            #if os(tvOS)
            actionButtons
                .tvFocusSection()
            HStack(alignment: .top, spacing: 60) {
                VStack(alignment: .leading, spacing: 20) {
                    worldSections
                }
                VStack(alignment: .leading, spacing: 20) {
                    townSections
                }
            }
            #else
            worldSections
            townSections
            actionButtons
            #endif
        }
        .padding(24)
        #if os(tvOS)
        .frame(width: 1400)
        #else
        .frame(minWidth: 360, idealWidth: 440)
        #endif
    }

    @ViewBuilder
    private var worldSections: some View {
        modeSection
        layoutSection
        seedSection
    }

    @ViewBuilder
    private var townSections: some View {
        cultureSection
        if viewModel.mode == .sandbox {
            ageSection
            difficultySection
        } else {
            scenarioSection
        }
    }

    private var actionButtons: some View {
        HStack {
            Button(GameText.string("common.cancel")) {
                viewModel.cancel()
                onCancel()
            }
            .cancelActionHotkey()
            Spacer()
            Button(GameText.string("newGame.start")) {
                if let world = viewModel.commit() {
                    onStart(world)
                }
            }
            .buttonStyle(.borderedProminent)
            .defaultActionHotkey()
            .disabled(!viewModel.isStartEnabled)
            .focused($startFocused)
            .accessibilityIdentifier("newGame.start")
        }
    }

    private var modeSection: some View {
        Picker(GameText.string("newGame.mode"), selection: $viewModel.mode) {
            Text(l10n: "newGame.sandbox").tag(NewGameDialogViewModel.Mode.sandbox)
            Text(l10n: "newGame.scenario").tag(NewGameDialogViewModel.Mode.scenario)
        }
        .pickerStyle(.segmented)
        .accessibilityIdentifier("newGame.mode")
    }

    private var difficultySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(l10n: "newGame.difficulty").font(.headline)
            Picker(GameText.string("newGame.difficulty"), selection: $viewModel.difficulty) {
                ForEach(Difficulty.allCases, id: \.self) { difficulty in
                    Text(difficulty.displayName).tag(difficulty)
                }
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("newGame.difficulty")
        }
    }

    private var scenarioSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(l10n: "newGame.scenario").font(.headline)
            Picker(GameText.string("newGame.scenario"), selection: $viewModel.scenario) {
                ForEach(Scenario.allCases, id: \.self) { scenario in
                    Text(scenario.title).tag(scenario)
                }
            }
            .pickerStyle(.menu)
            .accessibilityIdentifier("newGame.scenario")
            Text(viewModel.scenario.blurb)
                .font(.footnote)
                .foregroundStyle(.secondary)
            Text(verbatim: "\(viewModel.scenario.age.displayName) · \(viewModel.scenario.difficulty.displayName)")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
        }
    }

    private var ageSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(l10n: "newGame.startingAge").font(.headline)
            Picker(GameText.string("newGame.startingAge"), selection: $viewModel.age) {
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
            Text(l10n: "newGame.culture").font(.headline)
            Picker(GameText.string("newGame.culture"), selection: $viewModel.culture) {
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
            Text(l10n: "newGame.worldLayout").font(.headline)
            Picker(GameText.string("newGame.layout"), selection: $viewModel.layout) {
                Text(l10n: "newGame.singleIsland").tag(WorldLayout.singleIsland)
                Text(l10n: "newGame.archipelago").tag(WorldLayout.archipelago)
            }
            .pickerStyle(.segmented)
            .disabled(viewModel.isLayoutLocked)
            .accessibilityIdentifier("newGame.layout")
            if viewModel.showsRivalToggle {
                Toggle(GameText.string("newGame.rivalTowns"), isOn: $viewModel.rivalTowns)
                    .accessibilityIdentifier("newGame.rivalTowns")
            }
            // A campaign chapter that schedules events will hide this and run its schedule.
            Toggle(GameText.string("newGame.seasonalEvents"), isOn: $viewModel.seasonalEvents)
                .accessibilityIdentifier("newGame.seasonalEvents")
            Text(NewGameDialogViewModel.seasonalEventsHint)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var seedSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(l10n: "newGame.seed").font(.headline)
            Picker(GameText.string("newGame.seedMode"), selection: seedModeTag) {
                Text(l10n: "newGame.seedDefault").tag(SeedModeTag.default)
                Text(l10n: "newGame.seedRandom").tag(SeedModeTag.random)
                Text(l10n: "newGame.seedCustom").tag(SeedModeTag.custom)
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
            Text(l10n: "newGame.seedZero")
                .font(.caption)
                .foregroundStyle(.secondary)
        case let .random(captured):
            HStack {
                Text(l10n: "newGame.seedValue", "\(captured)")
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                Spacer()
                Button(GameText.string("newGame.reroll")) {
                    viewModel.useRandomSeed()
                }
                .buttonStyle(.borderless)
            }
        case .custom:
            TextField(GameText.string("newGame.customSeed"), text: customSeedBinding)
                #if !os(tvOS)
                .textFieldStyle(.roundedBorder)
                #endif
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
