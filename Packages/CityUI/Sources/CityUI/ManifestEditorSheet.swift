import CityCore
import SwiftUI

/// The port whose manifest the sheet edits, with its title and model
/// taken when the sheet opens.
struct ManifestEditTarget: Identifiable {
    let id: EntityID
    let title: String
    let model: ManifestEditorModel
}

/// Edits one port's manifest. Spec: `platform-shells` / Manifest editor
/// sheet.
struct ManifestEditorSheet: View {
    let title: String
    let model: ManifestEditorModel
    let onDone: ([ManifestAction]) -> Void
    @State private var draft: ManifestDraft
    @State private var verb: ManifestVerb = .load
    @State private var good: Good = .wood
    @State private var quantity = ManifestDraft.defaultQuantity
    @Environment(\.dismiss) private var dismiss

    init(title: String, model: ManifestEditorModel, actions: [ManifestAction], onDone: @escaping ([ManifestAction]) -> Void) {
        self.title = title
        self.model = model
        self.onDone = onDone
        _draft = State(initialValue: ManifestDraft(actions: actions))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(GameText.string("manifest.actions")) {
                    if draft.actions.isEmpty {
                        Text(l10n: "manifest.empty").foregroundStyle(.secondary)
                    }
                    ForEach(Array(draft.actions.enumerated()), id: \.offset) { _, action in
                        Text(model.line(for: action))
                    }
                    .onDelete { draft.remove(atOffsets: $0) }
                }
                Section(GameText.string("manifest.addSection")) {
                    Picker(GameText.string("manifest.action"), selection: $verb) {
                        Text(model.label(for: .load)).tag(ManifestVerb.load)
                        Text(model.label(for: .unload)).tag(ManifestVerb.unload)
                    }
                    .pickerStyle(.segmented)
                    Picker(GameText.string("manifest.good"), selection: $good) {
                        ForEach(model.rows(for: verb), id: \.good) { row in
                            Text(row.title).tag(row.good)
                        }
                    }
                    #if os(tvOS)
                    SteppedValueControl(
                        GameText.string("manifest.upTo"),
                        value: $quantity,
                        step: ManifestDraft.quantityStep,
                        range: ManifestDraft.quantityRange
                    )
                    #else
                    Stepper(
                        GameText.string("manifest.upToQuantity", quantity),
                        value: $quantity,
                        in: ManifestDraft.quantityRange,
                        step: ManifestDraft.quantityStep
                    )
                    #endif
                    Button(GameText.string("manifest.add", model.label(for: verb))) {
                        draft.add(verb, good: good, quantity: quantity)
                    }
                }
            }
            .navigationTitle(title)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(GameText.string("common.cancel")) { dismiss() }
                        .cancelActionHotkey()
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(GameText.string("common.done")) {
                        onDone(draft.actions)
                        dismiss()
                    }
                }
            }
        }
    }
}
