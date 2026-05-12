import CityCore
import Foundation

/// Per-good supply situation for the ghost preview's cost row. Spec
/// `add-construction-stalls` / `rendering-2_5d` Requirement: Ghost
/// preview status tints.
public enum CostStatus: Hashable, Sendable {
    /// The island already has the good in goods buffers (have ≥ need).
    case ok
    /// The island is short, but at least one operational producer on
    /// the island outputs the good. Placement is allowed; the building
    /// enters `.waitingForMaterials`.
    case queueable
    /// The island is short and no operational producer can supply.
    /// Placement is rejected.
    case blocked
}

/// One slot in `GameSession.GhostPreview.costBreakdown`. Lives at the
/// top level to satisfy SwiftLint's nesting-depth gate; the view-model
/// references the type as `GhostCost` rather than nesting it inside
/// `GhostPreview`.
public struct GhostCost: Hashable, Sendable {
    public let need: Int
    public let have: Int
    public let status: CostStatus

    public init(need: Int, have: Int, status: CostStatus = .ok) {
        self.need = need
        self.have = have
        self.status = status
    }

    public var isShort: Bool {
        have < need
    }
}
