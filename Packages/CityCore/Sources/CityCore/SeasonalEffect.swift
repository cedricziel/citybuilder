import Foundation

/// A seasonal event's mechanic, as its pack item names it. The generated
/// catalog uses it. Spec: `seasonal-events`.
public enum SeasonalEffect: String, Codable, Sendable {
    case fire, blight, fever, festival

    /// Fire, blight and fever harm the town and are warned a season ahead;
    /// the festival is a request.
    public var isHazard: Bool {
        self != .festival
    }
}

/// The moments a seasonal event shows a banner.
public enum SeasonalBannerKind: String, Codable, Sendable {
    case warning, onset, ignition, end, endNoLoss, endNoFire, request, held, missed
}

/// A banner's title and text, with placeholders CityUI fills.
public struct SeasonalBanner: Hashable, Sendable {
    public let title: String
    public let text: String

    public init(title: String, text: String) {
        self.title = title
        self.text = text
    }
}
