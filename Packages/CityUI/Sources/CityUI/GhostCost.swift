import CityCore
import Foundation

/// One slot in `GameSession.GhostPreview.costBreakdown`. Lives at the
/// top level to satisfy SwiftLint's nesting-depth gate; the view-model
/// references the type as `GhostCost` rather than nesting it inside
/// `GhostPreview`.
public struct GhostCost: Hashable, Sendable {
    public let need: Int
    public let have: Int

    public init(need: Int, have: Int) {
        self.need = need
        self.have = have
    }

    public var isShort: Bool {
        have < need
    }
}
