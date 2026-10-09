import CityCore
import Foundation

/// The manifest of one port while the player edits it. Spec:
/// `platform-shells` / Manifest editor sheet.
public struct ManifestDraft: Equatable, Sendable {
    public private(set) var actions: [ManifestAction]

    /// 5 to 100 in steps of 5; 100 is a ship's default capacity.
    public static let quantities = Array(stride(from: 5, through: ShipClass.default.capacity, by: 5))
    public static let defaultQuantity = 20

    public init(actions: [ManifestAction]) {
        self.actions = actions
    }

    public mutating func add(_ verb: ManifestVerb, good: Good, quantity: Int) {
        actions.append(verb == .load ? .loadUpTo(good: good, qty: quantity) : .unloadUpTo(good: good, qty: quantity))
    }

    public mutating func remove(at index: Int) {
        guard actions.indices.contains(index) else { return }
        actions.remove(at: index)
    }

    public mutating func remove(atOffsets offsets: IndexSet) {
        for index in offsets.sorted(by: >) {
            remove(at: index)
        }
    }
}

public extension ManifestEditorModel {
    /// "Load 20 Wood" at the player's port, "Buy 20 Wood — $5" at a
    /// rival's.
    func line(for action: ManifestAction) -> String {
        switch action {
        case let .loadUpTo(good, qty): line(.load, good: good, quantity: qty)
        case let .unloadUpTo(good, qty): line(.unload, good: good, quantity: qty)
        }
    }

    private func line(_ verb: ManifestVerb, good: Good, quantity: Int) -> String {
        let text = "\(label(for: verb)) \(quantity) \(GoodsCatalog.spec(for: good).displayName)"
        guard rival != nil else { return text }
        return "\(text) — \(Self.price(of: good, verb))"
    }
}

public extension ManifestGoodRow {
    /// "Wood", or at a rival port "Wood — $5 — 12" / "Iron — no offer".
    var title: String {
        let name = GoodsCatalog.spec(for: good).displayName
        return ([name] + [price, offer].compactMap(\.self)).joined(separator: " — ")
    }
}
