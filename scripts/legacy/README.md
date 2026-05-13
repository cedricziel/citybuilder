# Legacy / deprecated

> **DEPRECATION NOTICE.** Files in this directory are retained for
> reference only. They are NOT invoked by the current build pipeline
> and MUST NOT be referenced by the `Makefile`, `README.md`, or any CI
> workflow. A follow-up change will delete them.

## What's here

### `generate-sprites.swift`

The retired procedural sprite generator. Previously the single source
of truth for every sprite PNG under
`Resources/{Terrain,Buildings,Units,Icons}.atlas/`. Each helper
(`drawSawBlade(angleStep:)`, `drawSmokeOffset`, `drawFlagWave`, …)
hand-drew pixels into a `Pixmap`. Adding a new building meant writing
tens to hundreds of lines of `Pixmap` draw code.

**Replacement:** `scripts/generate_sprites_ai/` — the AI sprite
pipeline driven by the natural-language catalog under
`Resources/Sprites.style/`. See
`openspec/changes/replace-procedural-sprites-with-ai-pipeline/` for the
migration record.

Keeping the legacy script here for one release so contributors can
diff against the procedural baselines if they need to understand how a
particular sprite was historically rendered. After the
`replace-procedural-sprites-with-ai-pipeline` change archives and one
release ships, a subsequent change SHALL delete this directory.
