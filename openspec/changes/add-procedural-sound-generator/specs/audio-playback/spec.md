## ADDED Requirements

### Requirement: Procedural sounds are generated in the repository

Every sound the project authors itself SHALL come from a recipe in `scripts/audio/`, rendered by `make audio` into a mono IMA4 `.caf` file under `Resources/Audio/`. Rendering MUST be deterministic: on any machine, the same recipes SHALL produce byte-identical files, so the generator MUST NOT depend on platform maths libraries or unseeded randomness. Each rendered sound SHALL be normalised to its bus's level: one-shots on the `sfx` bus by the RMS of their loudest 50 ms, and `loop` and `ambient` sounds by their overall RMS. No sample MAY exceed 0.95 of full scale. A generated sound's manifest entry SHALL name the generator as its author and source, under the CC0 license.

#### Scenario: Regenerating reproduces the committed sounds
- **WHEN** `make audio-check` renders every recipe
- **THEN** each result is byte-identical to the committed file, and the check exits 0

#### Scenario: A stale sound fails the check
- **WHEN** a recipe changes and its committed file is not regenerated
- **THEN** `make audio-check` names that file and exits non-zero

#### Scenario: Generated sounds open on Apple platforms
- **WHEN** CityAudio opens each bundled sound with `AVAudioFile`
- **THEN** every file opens with at least one frame
