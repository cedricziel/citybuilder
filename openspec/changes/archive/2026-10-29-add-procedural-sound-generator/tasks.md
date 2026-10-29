## 1. Generator

- [x] 1.1 Tests first: the regeneration check, the IMA4 round trip and the deterministic maths, in `scripts/tests/test_audio_generator.py`
- [x] 1.2 `scripts/audio/dsp.py`: polynomial sine and exponential, xorshift random numbers, filters, struck modes and loudness normalisation
- [x] 1.3 `scripts/audio/caf.py`: IMA4 encoder whose output Apple's decoder reads back bit for bit (checked with `afconvert`)
- [x] 1.4 `make audio` and `make audio-check`

## 2. Replace the placeholders

- [x] 2.1 Recipes for the sawmill, lumberjack, carrier clink and forest-birds bed; the generator writes their manifest entries, and `audio-check` fails when the manifest disagrees
- [x] 2.3 `audio-check` also runs on Linux, in the `changes` job
- [x] 2.2 A CityAudio test opens every bundled sound with `AVAudioFile`
