import Foundation

/// Who sends orders, as a template names it. The generated catalog uses it.
public enum OrderIssuerKind: String, Codable, Sendable {
    case crown, rival
}
