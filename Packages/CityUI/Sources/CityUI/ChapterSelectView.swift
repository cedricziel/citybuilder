import CityCore
import SwiftUI

/// Chapter select: campaigns and their chapters beside the chosen chapter,
/// collapsing to a list on iPhone (canvas option C). Spec:
/// `platform-shells` / Campaigns on the title screen.
struct ChapterSelectView: View {
    @Bindable var model: ChapterSelectModel
    let onStart: (Chapter, World) -> Void
    let onClose: () -> Void
    @FocusState private var focusedRow: String?
    /// On iPhone the list shows first, though a chapter is chosen.
    @State private var compactColumn = NavigationSplitViewColumn.sidebar

    var body: some View {
        if model.isEmpty {
            NavigationStack {
                ContentUnavailableView {
                    Label(GameText.string("campaigns.title"), systemImage: "map")
                } description: {
                    Text(l10n: "campaigns.comingSoon")
                }
                .toolbar { closeButton }
            }
            .accessibilityIdentifier("campaigns.empty")
            .tvSheetWidth()
        } else {
            NavigationSplitView(preferredCompactColumn: $compactColumn) {
                sidebar
            } detail: {
                detail
            }
            .task(id: model.selectedID) {
                await model.loadSelectedMap()
            }
        }
    }

    private var closeButton: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button(GameText.string("common.close"), action: onClose).cancelActionHotkey()
        }
    }

    /// The sidebar's selection: on iPhone, where the split view collapses
    /// to a stack, choosing a row pushes the chapter.
    private var selection: Binding<String?> {
        Binding(get: { model.selectedID }, set: { id in if let id { model.select(id) } })
    }

    private var sidebar: some View {
        #if os(tvOS)
        List { sidebarRows }
            .navigationTitle(GameText.string("campaigns.title"))
            .toolbar { closeButton }
            // Focus picks the chapter, as a sidebar does on Apple TV.
            .onChange(of: focusedRow) { _, id in
                if let id { model.select(id) }
            }
        #else
        List(selection: selection) { sidebarRows }
            .navigationTitle(GameText.string("campaigns.title"))
            .toolbar { closeButton }
        #endif
    }

    private var sidebarRows: some View {
        ForEach(model.sections) { section in
            Section {
                ForEach(section.rows) { row in
                    #if os(tvOS)
                    Button { model.select(row.id) } label: { rowLabel(row) }
                        .focused($focusedRow, equals: row.id)
                        .accessibilityIdentifier("campaigns.chapter.\(row.id)")
                    #else
                    NavigationLink(value: row.id) { rowLabel(row) }
                        .accessibilityIdentifier("campaigns.chapter.\(row.id)")
                    #endif
                }
            } header: {
                HStack {
                    Text(section.title)
                    Spacer()
                    Text(section.tally).monospacedDigit()
                }
            }
        }
    }

    private func rowLabel(_ row: ChapterSelectModel.Row) -> some View {
        HStack(spacing: 10) {
            Text(verbatim: "\(row.number)").monospacedDigit().foregroundStyle(.secondary).frame(minWidth: 18)
            VStack(alignment: .leading, spacing: 2) {
                Text(row.title)
                Text(row.status).font(.caption).foregroundStyle(statusColor(row.state))
            }
            Spacer(minLength: 4)
            switch row.state {
            case .won: Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
            case .locked, .comingLater: Image(systemName: "lock.fill").foregroundStyle(.tertiary)
            case .open: EmptyView()
            }
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }

    private func statusColor(_ state: ChapterSelectModel.RowState) -> Color {
        switch state {
        case .won: .green
        case .open: .accentColor
        case .locked, .comingLater: .secondary
        }
    }

    @ViewBuilder
    private var detail: some View {
        if let chapter = model.selected {
            ScrollView {
                ChapterDetailView(model: model, chapter: chapter, mapImage: model.selectedMap) { world in onStart(chapter, world) }
            }
            .navigationTitle(chapter.title)
            #if !os(tvOS)
            .navigationBarTitleDisplayModeInline()
            #endif
        }
    }
}

/// The chosen chapter: its map, card text, goals, start and limits, the
/// picks and Start.
struct ChapterDetailView: View {
    @Bindable var model: ChapterSelectModel
    let chapter: Chapter
    let mapImage: CGImage?
    let onStart: (World) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ChapterMapHeader(image: mapImage)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            if let eyebrow = model.selectedEyebrow {
                Text(eyebrow).font(.footnote).textCase(.uppercase).foregroundStyle(.secondary)
            }
            Text(chapter.title).font(.largeTitle.bold()).accessibilityAddTraits(.isHeader)
            Text(chapter.intro).fixedSize(horizontal: false, vertical: true)
            goals
            facts
            picks
            startButton
        }
        .padding(24)
        .frame(maxWidth: 720, alignment: .leading)
    }

    private var culture: Culture {
        chapter.culture ?? model.culture
    }

    private var goals: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(l10n: "goals.title").font(.headline)
            ForEach(Array(chapter.goals.filter { !$0.isBonus }.enumerated()), id: \.offset) { _, goal in
                Text(ChapterText.goal(goal, culture: culture))
            }
            let bonus = chapter.goals.filter(\.isBonus)
            if !bonus.isEmpty {
                Text(l10n: "goals.bonusHeader").font(.headline).padding(.top, 6)
                ForEach(Array(bonus.enumerated()), id: \.offset) { _, goal in
                    Text(ChapterText.goal(goal, culture: culture)).foregroundStyle(.secondary)
                }
            }
        }
    }

    private var facts: some View {
        VStack(alignment: .leading, spacing: 6) {
            LabeledContent(GameText.string("chapter.starts"), value: ChapterText.start(chapter))
            LabeledContent(GameText.string("chapter.lostIf"), value: ChapterText.lostIf(chapter.loseConditions(for: model.difficulty)))
            LabeledContent(GameText.string("chapter.reward"), value: ChapterText.reward(chapter.reward))
        }
        .font(.callout)
    }

    @ViewBuilder
    private var picks: some View {
        Picker(GameText.string("newGame.difficulty"), selection: $model.difficulty) {
            ForEach(model.difficulties, id: \.self) { Text($0.displayName).tag($0) }
        }
        .pickerStyle(.segmented)
        .accessibilityIdentifier("campaigns.difficulty")
        if model.showsCulturePicker {
            Picker(GameText.string("newGame.culture"), selection: $model.culture) {
                ForEach(Culture.allCases, id: \.self) { Text($0.displayName).tag($0) }
            }
            .pickerStyle(.menu)
            .accessibilityIdentifier("campaigns.culture")
        } else if let culture = chapter.culture {
            LabeledContent(GameText.string("newGame.culture"), value: culture.displayName).font(.callout)
        }
    }

    private var startButton: some View {
        Button {
            if let world = model.makeWorld() { onStart(world) }
        } label: {
            Text(model.blockedReason ?? "Start chapter").frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .disabled(!model.canStart)
        .defaultActionHotkey()
        .accessibilityIdentifier("campaigns.start")
    }
}

private extension View {
    func navigationBarTitleDisplayModeInline() -> some View {
        #if os(iOS)
        navigationBarTitleDisplayMode(.inline)
        #else
        self
        #endif
    }
}
