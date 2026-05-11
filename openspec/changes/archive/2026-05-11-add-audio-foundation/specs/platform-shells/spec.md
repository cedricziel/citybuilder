## ADDED Requirements

### Requirement: iOS audio session category

On iOS and iPadOS, the app SHALL configure the `AVAudioSession` shared instance to category `.ambient` on first audio activation. This category MUST allow the user's own music to continue playing alongside the game. The category MUST NOT be set at app launch — it MUST be deferred until the audio engine starts (first cue).

#### Scenario: Player's music keeps playing

- **WHEN** the user is playing Apple Music or Spotify and launches the game on iPhone or iPad
- **THEN** their music continues uninterrupted; if the in-game music plays, both mix

#### Scenario: Audio session not activated at launch

- **WHEN** the iOS app launches and the player has not yet caused any audio event
- **THEN** `AVAudioSession.sharedInstance().category` retains its pre-launch value (not yet set to `.ambient`)

### Requirement: iOS interruption handling

On iOS and iPadOS, the audio layer SHALL observe `AVAudioSession.interruptionNotification`. On an interruption-began notification, the engine MUST pause playback on all four buses. On an interruption-ended notification with the `shouldResume` option set, the engine MUST resume playback. The simulation tick loop MUST be unaffected — interruptions affect audio only.

#### Scenario: Phone call pauses audio

- **WHEN** a phone call begins while the iOS app is in the foreground
- **THEN** the audio engine pauses within one render cycle, and the simulation tick continues advancing without interruption

#### Scenario: Phone call ends resumes audio

- **WHEN** the phone call ends and `AVAudioSession` posts an `interruptionEnded` with `shouldResume`
- **THEN** the audio engine resumes playback

### Requirement: macOS audio session no-op

On macOS, no `AVAudioSession` configuration SHALL be required or attempted. The audio engine MUST function correctly on macOS using `AVAudioEngine` alone. Interruption-handling code paths MUST be compiled out (or no-op) on macOS targets.

#### Scenario: Mac build links without AudioSession

- **WHEN** the `CitybuilderMac` target is compiled
- **THEN** no reference to `AVAudioSession` is emitted in the macOS binary

### Requirement: Settings exposes audio sliders

The platform Settings surface SHALL expose a music-volume slider, an SFX-volume slider (each 0.0–1.0), and a master-mute toggle. The settings panel MUST also expose a "Credits & Licenses" entry that opens `CreditsView`.

#### Scenario: Settings has audio sliders

- **WHEN** the user opens Settings on any platform
- **THEN** music-volume, SFX-volume, and mute controls are visible

#### Scenario: Settings exposes credits

- **WHEN** the user opens Settings on any platform
- **THEN** a "Credits & Licenses" row is visible and tappable
