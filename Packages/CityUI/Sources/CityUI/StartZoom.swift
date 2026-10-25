import CityCore

/// How close a new game's camera starts. One tile is 64 points wide at
/// zoom 1 whatever the screen, so a phone's 402 points show about six
/// tiles: the town center fills most of the width and no coast shows.
/// Spec: `platform-shells` / Start zoom per device.
public enum StartZoom {
    /// A phone shows the town center a third of the screen wide, with open
    /// ground and the coast around it; houses still read.
    public static let phone = 0.55
    /// Every other device keeps the camera's own default.
    public static let standard = Camera().zoom

    public static func zoom(for idiom: HUDIdiom) -> Double {
        idiom == .phone ? phone : standard
    }
}
