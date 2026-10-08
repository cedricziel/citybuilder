#!/usr/bin/env bash
# Fast pre-commit gate: if a catalog edit is staged, at least one of its
# sheets (`_sheets/<id>.png` or `_sheets/<id>-*.png`) MUST be staged too. Otherwise the next CI offline regen will produce
# different atlas bytes than what's committed and the build will fail.
#
# This hook does NOT enforce the reverse direction — a sheet-only edit
# (e.g., after a model bump or a manual re-encode) is allowed.
#
# Spec: sprite-asset-pipeline § "Hermetic regeneration via make sprites"
# scenario `CI fails on a cache miss` — this hook turns that
# guaranteed CI failure into a pre-commit error so it never lands.

set -euo pipefail

# Names of staged catalog edits, without the .md suffix.
catalog_changes=()
while IFS= read -r line; do
    catalog_changes+=("$line")
done < <(
    git diff --cached --name-only \
        --diff-filter=ACMR \
        -- 'Resources/Sprites.style/catalog/*.md' \
    | sed -E 's|Resources/Sprites.style/catalog/(.*)\.md|\1|'
)

if [ ${#catalog_changes[@]} -eq 0 ]; then
    exit 0
fi

# Names of staged sheet edits, without the .png suffix.
sheet_changes=()
while IFS= read -r line; do
    sheet_changes+=("$line")
done < <(
    git diff --cached --name-only \
        --diff-filter=ACMR \
        -- 'Resources/Sprites.style/_sheets/*.png' \
    | sed -E 's|Resources/Sprites.style/_sheets/(.*)\.png|\1|'
)

missing=()
for id in "${catalog_changes[@]}"; do
    found=0
    for s in "${sheet_changes[@]:-}"; do
        # One sheet per sprite: an entry's sheets are `<id>.png` plus
        # `<id>-<suffix>.png` for its frames and variants.
        if [ "$s" = "$id" ] || [[ "$s" == "$id"-* ]]; then
            found=1
            break
        fi
    done
    if [ $found -eq 0 ]; then
        missing+=("$id")
    fi
done

if [ ${#missing[@]} -gt 0 ]; then
    echo "ERROR: catalog edits without matching sheet edits:" >&2
    for id in "${missing[@]}"; do
        echo "  - Resources/Sprites.style/catalog/${id}.md was edited" >&2
        echo "    but Resources/Sprites.style/_sheets/${id}.png is unchanged." >&2
    done
    echo "" >&2
    echo "Run \`make sprites\` to regenerate the matching sheet(s) and" >&2
    echo "commit them in the same commit. CI's \`make sprites-verify\`" >&2
    echo "will otherwise reject this change for not reproducing offline." >&2
    exit 1
fi

exit 0
