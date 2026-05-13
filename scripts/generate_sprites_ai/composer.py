"""Pure prompt-assembly module.

`compose_prompt(world_md, entry_md, fixed_instructions) -> str` produces
the natural-language instruction string sent as `prompt=` to
OpenAI's `/v1/images/edits`. It is a pure function — equal inputs
produce equal output bytes — so its hash forms a stable cache key.

There is no I/O and no network access in this module.
"""

from __future__ import annotations


# Fixed-instructions block. Bumping this string invalidates every cache
# entry (it is part of every cache key). Kept short and stable — the
# bulk of the prompt comes from world.md and the per-sprite catalog
# entry. The text below is the *only* prompt directive the pipeline
# adds outside the catalog; everything else must originate from the
# style bible.
FIXED_INSTRUCTIONS = (
    "You are generating a single sprite SHEET for a 2:1 isometric "
    "pixel-art game.\n"
    "\n"
    "STRICT OUTPUT FORMAT:\n"
    "- One PNG image at the requested sheet dimensions.\n"
    "- The sheet is divided into a uniform grid of cells as declared "
    "in the catalog entry's `## Sheet` section.\n"
    "- Each cell shows ONE sprite frame in the position declared by "
    "the (row, col) line for that cell.\n"
    "- Spare cells MUST be filled with solid `#FF00FF` magenta. They "
    "are placeholders; do not invent content for them.\n"
    "- Every cell that contains an asset MUST keep the cell's "
    "background filled with `#FF00FF` magenta outside the sprite "
    "silhouette. This magenta is post-processed to alpha=0; do not "
    "use any other colour for the background.\n"
    "- DO NOT include any text, labels, watermarks, borders, or UI "
    "chrome.\n"
    "- DO NOT use anti-aliased edges or gradients. All boundaries "
    "are crisp pixel transitions.\n"
    "- DO NOT introduce stylistic variation between cells of the same "
    "sprite — every cell shares one canonical design, identity, "
    "outline weight, and palette.\n"
    "- Animation frames vary ONLY the moving element declared in the "
    "catalog entry's `## Animation` section; the rest of the sprite "
    "is pixel-identical across frames.\n"
)


def compose_prompt(world_md: str, entry_md: str, fixed_instructions: str) -> str:
    """Compose a generation prompt from the style bible, a catalog
    entry, and the fixed-instructions block.

    Pure function. Equal inputs ⇒ equal output. No I/O.
    """
    parts = [
        fixed_instructions.strip(),
        "",
        "=== WORLD STYLE BIBLE ===",
        world_md.strip(),
        "",
        "=== PER-SPRITE CATALOG ENTRY ===",
        entry_md.strip(),
    ]
    return "\n".join(parts) + "\n"
