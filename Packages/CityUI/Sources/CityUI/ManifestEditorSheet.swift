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
                Section("Actions") {
                    if draft.actions.isEmpty {
                        Text("No actions yet. Ships stop here and sail on.").foregroundStyle(.secondary)
                    }
                    ForEach(Array(draft.actions.enumerated()), id: \.offset) { _, action in
                        Text(model.line(for: action))
                    }
                    .onDelete { draft.remove(atOffsets: $0) }
                }
                Section("Add") {
                    Picker("Action", selection: $verb) {
                        Text(model.label(for: .load)).tag(ManifestVerb.load)
                        Text(model.label(for: .unload)).tag(ManifestVerb.unload)
                    }
                    .pickerStyle(.segmented)
                    Picker("Good", selection: $good) {
                        ForEach(model.rows(for: verb), id: \.good) { row in
                            Text(row.title).tag(row.good)
                        }
                    }
                    Stepper(
                        "Up to \(quantity)",
                        value: $quantity,
                        in: ManifestDraft.quantityRange,
                        step: ManifestDraft.quantityStep
                    )
                    Button("Add \(model.label(for: verb))") {
                        draft.add(verb, good: good, quantity: quantity)
                    }
                }
            }
            .navigationTitle(title)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        onDone(draft.actions)
                        dismiss()
                    }
                }
            }
        }
    }
}
