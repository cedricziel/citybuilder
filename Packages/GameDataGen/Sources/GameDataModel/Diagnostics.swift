/// One problem in the game data, printed as `file:line: Kind id: message`.
public struct Diagnostic: Equatable, Sendable, CustomStringConvertible {
    public var origin: Origin
    /// `Kind id` of the item, when the problem belongs to one.
    public var item: String?
    public var message: String

    public var description: String {
        "\(origin): " + (item.map { "\($0): " } ?? "") + message
    }
}

public struct GameDataErrors: Error, Sendable, CustomStringConvertible {
    public var diagnostics: [Diagnostic]

    public var description: String {
        diagnostics.map(\.description).joined(separator: "\n")
    }
}

/// Collects diagnostics so one run reports every problem.
final class DiagnosticLog {
    private(set) var diagnostics: [Diagnostic] = []

    func error(_ message: String, at origin: Origin, item: String? = nil) {
        diagnostics.append(Diagnostic(origin: origin, item: item, message: message))
    }
}
