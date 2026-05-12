import AVFoundation
import Foundation

/// Cross-platform audio session configuration. The iOS implementation sets
/// the shared `AVAudioSession` category to `.playback` with the
/// `.mixWithOthers` option so the game plays audio regardless of the
/// device's Silent Mode switch while still letting the user's own music
/// (Apple Music, Spotify) continue alongside. Also observes interruption
/// notifications (phone calls, Siri) to pause and resume the engine.
/// The macOS implementation is a no-op — AVAudioEngine alone is sufficient
/// on Mac.
///
/// The original design used `.ambient` (the standard "respects Silent Mode"
/// category) but Silent-Mode-muted iPads heard nothing, which is the wrong
/// default for a game the user explicitly launched. `.playback` with
/// `.mixWithOthers` is the conventional games-audio category.
///
/// Per spec `platform-shells` "iOS audio session category" + "iOS
/// interruption handling" + "macOS audio session no-op".
@MainActor
public final class PlatformAudioSession {
    private weak var engine: AudioEngine?
    private var activated = false

    public init(engine: AudioEngine) {
        self.engine = engine
    }

    /// Configure the platform audio session category + active state without
    /// touching any per-engine state (no interruption observer, no bookkeeping).
    /// Call BEFORE constructing `AVAudioEngine` so the engine's mandatory
    /// session association at attach/connect time finds a valid session — on
    /// iOS, deferring this until after `AVAudioEngine()` triggers a -10879
    /// (`kAudioUnitErr_InvalidParameter`) "associating with audio session
    /// (0x0)" log at engine construction.
    ///
    /// On macOS this is a no-op (no session to configure).
    public static func configureSessionEarly() {
        #if os(iOS) || os(tvOS) || os(visionOS)
        try? AVAudioSession.sharedInstance().setCategory(
            .playback,
            mode: .default,
            options: [.mixWithOthers]
        )
        try? AVAudioSession.sharedInstance().setActive(true)
        #endif
    }

    /// True once `activate()` has been called and (on iOS) the audio
    /// session has been configured.
    public var isActivated: Bool {
        activated
    }

    /// Lazily configure the platform's audio session. Called on the first
    /// cue dispatch — never at app launch — so silent cold-launches do
    /// not interfere with the user's existing audio.
    public func activate() throws {
        guard !activated else { return }
        #if os(iOS) || os(tvOS) || os(visionOS)
        try AVAudioSession.sharedInstance().setCategory(
            .playback,
            mode: .default,
            options: [.mixWithOthers]
        )
        try AVAudioSession.sharedInstance().setActive(true)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleInterruption(_:)),
            name: AVAudioSession.interruptionNotification,
            object: nil
        )
        #endif
        activated = true
    }

    #if os(iOS) || os(tvOS) || os(visionOS)
    @objc private func handleInterruption(_ notification: Notification) {
        guard let info = notification.userInfo,
              let typeValue = info[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue)
        else { return }
        switch type {
        case .began:
            engine?.stop()
        case .ended:
            if let optionsValue = info[AVAudioSessionInterruptionOptionKey] as? UInt {
                let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
                if options.contains(.shouldResume) {
                    try? engine?.start()
                }
            }
        @unknown default:
            break
        }
    }
    #endif
}
