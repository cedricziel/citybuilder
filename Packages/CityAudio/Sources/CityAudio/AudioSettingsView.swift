#if canImport(SwiftUI)
import SwiftUI

/// SwiftUI view that binds an `AudioSettings` model to user-facing sliders
/// and a mute toggle. Per spec `platform-shells` "Settings exposes audio
/// sliders". Embed in the platform Settings surface.
///
/// Lives in `CityAudio` rather than `CityUI` so the package boundary stays
/// clean — `CityAudio` already owns `AudioSettings`; rendering it doesn't
/// pull AVFoundation into `CityUI`.
@available(iOS 18, macOS 15, *)
public struct AudioSettingsView: View {
    @State private var musicVolume: Float
    @State private var sfxVolume: Float
    @State private var isMuted: Bool
    private let settings: AudioSettings

    public init(settings: AudioSettings) {
        self.settings = settings
        _musicVolume = State(initialValue: settings.musicVolume)
        _sfxVolume = State(initialValue: settings.sfxVolume)
        _isMuted = State(initialValue: settings.isMuted)
    }

    public var body: some View {
        Form {
            Section {
                Toggle("Mute all audio", isOn: $isMuted)
                    .onChange(of: isMuted) { _, newValue in
                        settings.isMuted = newValue
                    }
            }
            Section("Volume") {
                LabeledContent("Music") {
                    Slider(value: $musicVolume, in: 0 ... 1)
                        .onChange(of: musicVolume) { _, newValue in
                            settings.musicVolume = newValue
                        }
                }
                LabeledContent("SFX") {
                    Slider(value: $sfxVolume, in: 0 ... 1)
                        .onChange(of: sfxVolume) { _, newValue in
                            settings.sfxVolume = newValue
                        }
                }
            }
        }
    }
}
#endif
