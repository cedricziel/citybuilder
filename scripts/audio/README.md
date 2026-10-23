# Generated audio

Every sound and piece of music the project authors comes from this directory:

- `sounds.py`: recipes for the sound effects, workshop loops, ambient beds and interface sounds. Run `make audio`, or `make audio-check` to compare.
- `music/`: the score language (`score.py`), the band (`synth.py`) and the scores (`pieces.py`). Run `make music`, or `make music-check` to compare; both need numpy (`PYTHON=…` picks the interpreter).

Renders are byte-identical on every machine, so a changed recipe or score shows up as changed `.caf` files.

## Keep the repository small

Each full music render rewrites about 10 MB of `.caf`, and git keeps every version for good.

- Don't re-render the music casually.
- Batch score changes into one commit.
- Render only the pieces that changed: `cd scripts && "${PYTHON:-python3}" -m audio.music.render --only music/<piece>.caf`.
- A change to `synth.py` or `score.py` changes every piece. Make it only when it's worth that cost.
