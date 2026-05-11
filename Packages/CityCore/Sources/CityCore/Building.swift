import Foundation

/// Building identifier used by spec scenarios that test placement validity
/// without yet referring to the full building catalog (which lands in M3).
public enum BuildingKind: String, CaseIterable, Codable, Sendable {
    case house
    case warehouse
    case road
    case lumberjackHut = "lumberjack_hut"
    case sawmill
    case townCenter = "town_center"
}
