"""Sprite generation orchestrator.

This is the only impure module in the pipeline: it makes network calls
to OpenAI, reads/writes the cache, and writes per-cell PNGs into the
category atlases. Pure helpers (`composer`, `slicer`, `postprocess`,
`cache`) do the rest.

The full implementation lands in M4; this stub exists so `make sprites`
is dispatchable from M3 onwards without crashing. The stub honours the
"`make sprites` MUST NOT regenerate `master-reference.png`" invariant
trivially (it never touches that file).
"""

from __future__ import annotations


def run_pipeline(offline: bool = False, verify: bool = False) -> int:
    """Stub implementation. Real orchestration lands in M4 task 5.4.

    Honours invariants:
    - Never touches `Resources/Sprites.style/master-reference.png`.
    - Exits 0 (success / no-op) so `make sprites` is callable during
      M3-era development.
    """
    mode = "verify" if verify else ("offline" if offline else "online")
    print(
        f"[batcher stub] {mode}: full pipeline lands in M4 task 5.4. "
        "Skipping for now — `master-reference.png` is left untouched.",
        flush=True,
    )
    return 0
