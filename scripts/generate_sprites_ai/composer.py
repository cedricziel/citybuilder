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
    "pixel-art game. The output MUST be a PNG with REAL TRANSPARENCY: "
    "every pixel outside the sprite silhouette is alpha=0 in the "
    "returned bytes. The API call is configured with "
    "`background: \"transparent\"`; honour it. Do not paint a coloured "
    "background; do not paint anything outside the silhouette of each "
    "cell's sprite.\n"
    "\n"
    "STRICT OUTPUT FORMAT:\n"
    "- One PNG image at the requested sheet dimensions, with per-pixel "
    "alpha.\n"
    "- The sheet is divided into a uniform grid of cells as declared "
    "in the catalog entry's `## Sheet` section.\n"
    "- Each cell shows ONE sprite frame in the position declared by "
    "the (row, col) line for that cell.\n"
    "- Pixels outside the sprite silhouette WITHIN every cell are "
    "alpha=0 — fully transparent.\n"
    "- `spare` cells are fully transparent end-to-end. Paint nothing "
    "in them.\n"
    "- DO NOT include any text, labels, watermarks, borders, cell "
    "outlines, or UI chrome anywhere on the sheet.\n"
    "- DO NOT use anti-aliased edges or gradients. All silhouette "
    "boundaries are crisp pixel transitions; the post-processor "
    "thresholds soft alpha to binary 0/255 to keep them that way.\n"
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
