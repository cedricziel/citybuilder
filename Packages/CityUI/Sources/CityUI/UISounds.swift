/// The interface's sounds, by the name `bindings.json` binds as `ui.<name>`.
/// Spec: `platform-shells` / Interface actions make a sound.
public enum UISound: String, CaseIterable, Sendable {
    case tap, select, toggle, open, close, reject
}

/// Where interface sounds go. App shells set `sink` at launch to the audio
/// layer, so CityUI never imports it; with no sink the interface is silent.
@MainActor
public enum UISounds {
    public static var sink: ((UISound) -> Void)?

    public static func play(_ sound: UISound) {
        sink?(sound)
    }
}
