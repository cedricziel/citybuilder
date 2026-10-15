#!/usr/bin/env bash
# Warns about tracked Swift files within HEADROOM lines of SwiftLint's
# file_length limit, before a merge pushes one over it and fails lint
# for everyone. It never fails: the limit itself is SwiftLint's job.
#
# The limit is file_length's warning value in .swiftlint.yml, which
# `swiftlint --strict` enforces as an error.
#
# Usage: scripts/check-file-length-headroom.sh
# Env:   HEADROOM (default 50)
set -euo pipefail

cd "$(dirname "$0")/.."
headroom=${HEADROOM:-50}
limit=$(awk '/^file_length:/ { in_block = 1; next }
             in_block && /^[^ ]/ { exit }
             in_block && $1 == "warning:" { print $2; exit }' .swiftlint.yml)
if [ -z "$limit" ]; then
    echo "check-file-length-headroom: no file_length warning in .swiftlint.yml" >&2
    exit 1
fi
threshold=$((limit - headroom))

found=0
while IFS= read -r -d '' file; do
    lines=$(wc -l <"$file" | tr -d ' ')
    if [ "$lines" -gt "$threshold" ]; then
        found=$((found + 1))
        message="$lines lines; SwiftLint fails this file above $limit. Split it before it grows."
        if [ -n "${GITHUB_ACTIONS:-}" ]; then
            echo "::warning file=$file,title=File near the length limit::$message"
        else
            echo "$file: $message"
        fi
    fi
done < <(git ls-files -z -- 'Apps/*.swift' 'CLI/*.swift' 'Packages/*.swift')

echo "$found Swift file(s) over $threshold lines (SwiftLint limit $limit, headroom $headroom)."
