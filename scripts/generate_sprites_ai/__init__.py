"""AI sprite generation pipeline for Citybuilder.

See:
- `Resources/Sprites.style/world.md` — style bible (single source of truth
  for the world's visual identity)
- `Resources/Sprites.style/catalog/<id>.md` — per-sprite catalog entries
- `Resources/Sprites.style/pipeline.toml` — model + concurrency pins
- `openspec/specs/sprite-style-catalog/spec.md` — capability spec
- `openspec/specs/sprite-asset-pipeline/spec.md` — output naming grammar

The pipeline is split into pure modules (`composer`, `slicer`,
`postprocess`, `cache`, `reference`) and an impure orchestrator
(`batcher`). The CLI entry point is `python -m generate_sprites_ai`.
"""
