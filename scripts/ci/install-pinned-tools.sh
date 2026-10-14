#!/usr/bin/env bash
# Installs the tools whose versions change CI results, at pinned
# versions verified by SHA-256, so a runner image or Homebrew update
# can't change lint results or sprite bytes. This file is the one place
# the versions live; README "Prerequisites" points here.
#
#   scripts/ci/install-pinned-tools.sh lint       SwiftFormat, SwiftLint, pre-commit
#   scripts/ci/install-pinned-tools.sh sprites    libimagequant (decides the atlas PNG bytes) and jpeg-turbo
#   scripts/ci/install-pinned-tools.sh versions   print the pinned versions
set -euo pipefail

SWIFTFORMAT_VERSION=0.63.1
SWIFTFORMAT_SHA256=385ef1a263ba28685157b98c5536b9c9105e124518f28b7ef8a2bee4b167eaeb

SWIFTLINT_VERSION=0.65.1
SWIFTLINT_SHA256=c1e429b0599cf1b516f369a2d9ec04eaf0e436f3c12b637df8851fa52ff694d0

PRE_COMMIT_VERSION=4.6.2

# `make sprites-verify` compares PNG bytes, and the quantizer decides
# them, so a new libimagequant can change every atlas PNG. Homebrew
# bottle digests come from https://formulae.brew.sh/api/formula/libimagequant.json
LIBIMAGEQUANT_VERSION=4.4.1

work="${RUNNER_TEMP:-$(mktemp -d)}/pinned-tools"
bin="$work/bin"

fetch() { # url sha256 dest [curl args...]
    local url="$1" sha="$2" dest="$3"
    shift 3
    curl --fail --silent --show-error --location --retry 3 "$@" "$url" -o "$dest"
    echo "$sha  $dest" | shasum -a 256 -c -
}

expect_version() { # tool want got
    echo "$1 $3"
    [[ "$3" == "$2" ]] || {
        echo "$1: want $2, got $3" >&2
        exit 1
    }
}

install_lint() {
    mkdir -p "$bin"
    fetch "https://github.com/nicklockwood/SwiftFormat/releases/download/$SWIFTFORMAT_VERSION/swiftformat.zip" \
        "$SWIFTFORMAT_SHA256" "$work/swiftformat.zip"
    unzip -o -q "$work/swiftformat.zip" -d "$work/swiftformat"
    install -m 0755 "$work/swiftformat/swiftformat" "$bin/swiftformat"

    fetch "https://github.com/realm/SwiftLint/releases/download/$SWIFTLINT_VERSION/portable_swiftlint.zip" \
        "$SWIFTLINT_SHA256" "$work/swiftlint.zip"
    unzip -o -q "$work/swiftlint.zip" -d "$work/swiftlint"
    install -m 0755 "$work/swiftlint/swiftlint" "$bin/swiftlint"

    python3 -m venv "$work/pre-commit"
    "$work/pre-commit/bin/pip" install --quiet "pre-commit==$PRE_COMMIT_VERSION"
    ln -sf "$work/pre-commit/bin/pre-commit" "$bin/pre-commit"

    if [[ -n "${GITHUB_PATH:-}" ]]; then echo "$bin" >>"$GITHUB_PATH"; fi
    expect_version swiftformat "$SWIFTFORMAT_VERSION" "$("$bin/swiftformat" --version)"
    expect_version swiftlint "$SWIFTLINT_VERSION" "$("$bin/swiftlint" version)"
    "$bin/pre-commit" --version
    echo "Pinned lint tools are in $bin; put it first on PATH."
}

install_sprites() {
    HOMEBREW_NO_AUTO_UPDATE=1 brew install jpeg-turbo
    local installed
    installed="$(brew list --versions libimagequant 2>/dev/null || true)"
    if [[ "$installed" != "libimagequant $LIBIMAGEQUANT_VERSION" ]]; then
        local tag sha
        case "$(uname -m)_$(sw_vers -productVersion | cut -d. -f1)" in
            arm64_26) tag=arm64_tahoe sha=9fe68c59c0500f834deced30fcd58c965148988f238d51791d39c6c284d71684 ;;
            arm64_15) tag=arm64_sequoia sha=35636b9bf13cd99e77dec879e87736122925c790fec18da07dbcbea76083bdc6 ;;
            *)
                echo "No pinned libimagequant bottle for this macOS; add its digest from" >&2
                echo "https://formulae.brew.sh/api/formula/libimagequant.json" >&2
                exit 1
                ;;
        esac
        mkdir -p "$work"
        local bottle="$work/libimagequant--$LIBIMAGEQUANT_VERSION.$tag.bottle.tar.gz"
        # ghcr.io serves public Homebrew bottles to this anonymous token.
        fetch "https://ghcr.io/v2/homebrew/core/libimagequant/blobs/sha256:$sha" "$sha" "$bottle" \
            -H "Authorization: Bearer QQ=="
        brew uninstall --ignore-dependencies libimagequant 2>/dev/null || true
        HOMEBREW_NO_AUTO_UPDATE=1 brew install "$bottle"
    fi
    expect_version libimagequant "libimagequant $LIBIMAGEQUANT_VERSION" "$(brew list --versions libimagequant)"
}

case "${1:-}" in
    lint) install_lint ;;
    sprites) install_sprites ;;
    versions)
        echo "SwiftFormat $SWIFTFORMAT_VERSION"
        echo "SwiftLint $SWIFTLINT_VERSION"
        echo "pre-commit $PRE_COMMIT_VERSION"
        echo "libimagequant $LIBIMAGEQUANT_VERSION"
        ;;
    *)
        echo "usage: $0 lint|sprites|versions" >&2
        exit 2
        ;;
esac
