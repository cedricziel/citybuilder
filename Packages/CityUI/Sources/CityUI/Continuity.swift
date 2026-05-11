import Foundation

/// Data carried in the NSUserActivity that advertises the current game via
/// Handoff. App shells construct an NSUserActivity with the type below
/// and the userInfo payload built here; the receiving device can decode
/// it to resume on the correct save.
public enum HandoffActivity {
    public static let activityType = "com.cedricziel.citybuilder.game"

    public struct Payload: Codable, Hashable, Sendable {
        public let gameID: UUID
        public let tickCount: UInt64
        public let device: String

        public init(gameID: UUID, tickCount: UInt64, device: String) {
            self.gameID = gameID
            self.tickCount = tickCount
            self.device = device
        }
    }

    public static func encode(_ payload: Payload) throws -> Data {
        try JSONEncoder().encode(payload)
    }

    public static func decode(_ data: Data) throws -> Payload {
        try JSONDecoder().decode(Payload.self, from: data)
    }
}
