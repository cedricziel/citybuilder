/// Something the core tells the player, as a catalog key and typed
/// arguments. CityCore never looks the key up; CityUI turns it into text in
/// the player's language. Spec: `localization`; design D4 of
/// `add-localization`.
public struct GameMessage: Hashable, Sendable {
    public let key: String
    public let args: [String: MessageArg]

    public init(_ key: String, _ args: [String: MessageArg] = [:]) {
        self.key = key
        self.args = args
    }
}

/// An argument of a `GameMessage`, typed so the UI can format it for the
/// player's language. Cases join as messages need them.
public enum MessageArg: Hashable, Sendable {
    case int(Int)
    case money(Int64)
}
