#if canImport(SwiftUI)
import CityUI
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
                Toggle(GameText.string("audio.muteAll"), isOn: $isMuted)
                    .onChange(of: isMuted) { _, newValue in
                        settings.isMuted = newValue
                    }
            }
            Section(GameText.string("audio.volume")) {
                valueControl(GameText.string("audio.music"), value: $musicVolume, range: 0 ... 1, step: 0.1, format: .percent)
                    .onChange(of: musicVolume) { _, newValue in
                        settings.musicVolume = newValue
                    }
                valueControl(GameText.string("audio.sfx"), value: $sfxVolume, range: 0 ... 1, step: 0.1, format: .percent)
                    .onChange(of: sfxVolume) { _, newValue in
                        settings.sfxVolume = newValue
                    }
            }
            Section(GameText.string("audio.spatial")) {
                Toggle(GameText.string("audio.spatial"), isOn: $spatialEnabled)
                    .onChange(of: spatialEnabled) { _, newValue in
                        settings.spatialAudioEnabled = newValue
                        onSpatialEnabledChange?(newValue)
                    }
                #if os(tvOS)
                spatialDistanceControls
                    .disabled(!spatialEnabled)
                #else
                DisclosureGroup(GameText.string("audio.advanced"), isExpanded: $advancedExpanded) {
                    spatialDistanceControls
                }
                .disabled(!spatialEnabled)
                #endif
            }
        }
    }

    @ViewBuilder
    private var spatialDistanceControls: some View {
        valueControl(GameText.string("audio.referenceDistance"), value: $spatialReference, range: 1 ... 16, step: 1, format: .integer)
            .onChange(of: spatialReference) { _, newValue in
                settings.spatialReferenceDistance = newValue
                onSpatialDistancesChange?(newValue, spatialMax)
            }
        valueControl(GameText.string("audio.maxDistance"), value: $spatialMax, range: 8 ... 64, step: 4, format: .integer)
            .onChange(of: spatialMax) { _, newValue in
                settings.spatialMaxDistance = newValue
                onSpatialDistancesChange?(spatialReference, newValue)
            }
    }

    /// A slider on iOS and Mac; a −/+ pair on Apple TV, which has no slider.
    @ViewBuilder
    private func valueControl(
        _ title: String,
        value: Binding<Float>,
        range: ClosedRange<Float>,
        step: Double,
        format: SteppedValue.Format
    ) -> some View {
        #if os(tvOS)
        SteppedValueControl(
            title,
            value: value,
            step: step,
            range: Double(range.lowerBound) ... Double(range.upperBound),
            format: format
        )
        #else
        LabeledContent(title) {
            Slider(value: value, in: range)
        }
        #endif
    }
}
#endif
