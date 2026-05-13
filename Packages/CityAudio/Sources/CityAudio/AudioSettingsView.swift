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
    @State private var spatialEnabled: Bool
    @State private var spatialReference: Float
    @State private var spatialMax: Float
    @State private var advancedExpanded: Bool = false
    private let settings: AudioSettings
    /// Fired when the user toggles spatial audio. App shells wire this to
    /// `AudioEngine.setSpatialEnabled` so the loop chain rebuilds live.
    /// Spec `audio-playback` "Spatial audio settings".
    private let onSpatialEnabledChange: ((Bool) -> Void)?
    /// Fired when reference / max distance changes. App shells wire this
    /// to `AudioEngine.setSpatialDistances` for live re-attenuation.
    private let onSpatialDistancesChange: ((Float, Float) -> Void)?

    public init(
        settings: AudioSettings,
        onSpatialEnabledChange: ((Bool) -> Void)? = nil,
        onSpatialDistancesChange: ((Float, Float) -> Void)? = nil
    ) {
        self.settings = settings
        self.onSpatialEnabledChange = onSpatialEnabledChange
        self.onSpatialDistancesChange = onSpatialDistancesChange
        _musicVolume = State(initialValue: settings.musicVolume)
        _sfxVolume = State(initialValue: settings.sfxVolume)
        _isMuted = State(initialValue: settings.isMuted)
        _spatialEnabled = State(initialValue: settings.spatialAudioEnabled)
        _spatialReference = State(initialValue: settings.spatialReferenceDistance)
        _spatialMax = State(initialValue: settings.spatialMaxDistance)
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
            Section("Spatial audio") {
                Toggle("Spatial audio", isOn: $spatialEnabled)
                    .onChange(of: spatialEnabled) { _, newValue in
                        settings.spatialAudioEnabled = newValue
                        onSpatialEnabledChange?(newValue)
                    }
                DisclosureGroup("Advanced", isExpanded: $advancedExpanded) {
                    LabeledContent("Reference distance") {
                        Slider(value: $spatialReference, in: 1 ... 16)
                            .onChange(of: spatialReference) { _, newValue in
                                settings.spatialReferenceDistance = newValue
                                onSpatialDistancesChange?(newValue, spatialMax)
                            }
                    }
                    LabeledContent("Max distance") {
                        Slider(value: $spatialMax, in: 8 ... 64)
                            .onChange(of: spatialMax) { _, newValue in
                                settings.spatialMaxDistance = newValue
                                onSpatialDistancesChange?(spatialReference, newValue)
                            }
                    }
                }
                .disabled(!spatialEnabled)
            }
        }
    }
}
#endif
