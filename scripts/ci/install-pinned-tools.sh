#!/usr/bin/env bash
# Installs the tools whose versions change CI results, at pinned
# versions verified by SHA-256, so a runner image or Homebrew update
# can't change lint results or sprite bytes. This file is the one place
# the versions live; README "Prerequisites" points here.
#
#   scripts/ci/install-pinned-tools.sh lint       SwiftFormat, SwiftLint, pre-commit
#   scripts/ci/install-pinned-tools.sh sprites    libimagequant (decides the atlas PNG bytes) and jpeg-turbo
#   scripts/ci/install-pinned-tools.sh xcodegen   XcodeGen
#   scripts/ci/install-pinned-tools.sh versions   print the pinned versions
#
# Limit of the Homebrew pins: Homebrew installs only the bottle its
# formula currently names, so the script cannot fetch an older version.
# Once a runner image's Homebrew moves a formula on (libimagequant
# 4.4.2, say), the digest check fails the job instead of installing the
# new bottle. Then bump the version and digests here and in the README,
# and for libimagequant re-render the atlases (`make sprites`) in the same
# PR.
#
# Not pinned here: zlib. Pillow links the zlib the runner image (or your
# macOS) ships, and it decides the compressed PNG bytes, so a new image
# can change atlas bytes without any formula changing.
set -euo pipefail

SWIFTFORMAT_VERSION=0.63.1
SWIFTFORMAT_SHA256=385ef1a263ba28685157b98c5536b9c9105e124518f28b7ef8a2bee4b167eaeb

SWIFTLINT_VERSION=0.65.1
SWIFTLINT_SHA256=c1e429b0599cf1b516f369a2d9ec04eaf0e436f3c12b637df8851fa52ff694d0

PRE_COMMIT_VERSION=4.6.2

# `art.finalize` quantizes every atlas PNG with it, so a new libimagequant
# can change every committed PNG. Bottle
# digests per macOS (27, 26, 15) come from
# https://formulae.brew.sh/api/formula/<formula>.json
LIBIMAGEQUANT_VERSION=4.4.1
LIBIMAGEQUANT_SHA256=(
    bc199055cc07090e3b88a54d48ae3d04502ff16dacb5c851846dc2719985cb09
    9fe68c59c0500f834deced30fcd58c965148988f238d51791d39c6c284d71684
    35636b9bf13cd99e77dec879e87736122925c790fec18da07dbcbea76083bdc6
)

JPEG_TURBO_VERSION=3.2.0
JPEG_TURBO_SHA256=(
    7bc0f7c007a73c68da8c11055e836de66c2814c1b0ca0302da9a6317199fd37a
    02539b0736cfacdc6c4bb6a7d274d0c5c8b6e1faf9b5bab1e155168961d288aa
    6dc55edcd33c693e474299ed2bba3c472ac1331cbe300066ec8ef99b88fab17c
)

XCODEGEN_VERSION=2.46.0
XCODEGEN_SHA256=(
    cc5980a1ffd679edf00e4204473b1cfa8c3abcce69c22c084d4d079b277e248b
    69a3584c1c9118cd37e45565b8679e1c84663e783e720c68e85ef6000a52c870
    0f06608766b94ca4ca5eb380ff38abfa908015f05c7f0eef41f22ac2a97c4288
)

work="${RUNNER_TEMP:-$(mktemp -d)}/pinned-tools"
bin="$work/bin"

fetch() { # url sha256 dest
    local url="$1" sha="$2" dest="$3"
    curl --fail --silent --show-error --location --retry 3 "$url" -o "$dest"
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

# Homebrew no longer installs a bottle from a local file, so let it
# fetch the bottle its formula names, check that bottle against the
# pinned digest, and install from that cached file.
install_bottle() { # formula version sha256-macos27 sha256-macos26 sha256-macos15
    local formula="$1" version="$2" sha
    case "$(uname -m)_$(sw_vers -productVersion | cut -d. -f1)" in
        arm64_27) sha="$3" ;;
        arm64_26) sha="$4" ;;
        arm64_15) sha="$5" ;;
        *)
            echo "No pinned $formula bottle for this macOS; add its digest from" >&2
            echo "https://formulae.brew.sh/api/formula/$formula.json" >&2
            exit 1
            ;;
    esac
    export HOMEBREW_NO_AUTO_UPDATE=1 HOMEBREW_NO_INSTALLED_DEPENDENTS_CHECK=1
    brew fetch --force "$formula"
    echo "$sha  $(brew --cache "$formula")" | shasum -a 256 -c - || {
        echo "$formula: Homebrew now names a different bottle than the pinned $version." >&2
        echo "Bump the pin (see the top of $0)." >&2
        exit 1
    }
    if brew list "$formula" >/dev/null 2>&1; then
        brew reinstall "$formula"
    else
        brew install "$formula"
    fi
    expect_version "$formula" "$formula $version" "$(brew list --versions "$formula")"
}

install_sprites() {
    install_bottle jpeg-turbo "$JPEG_TURBO_VERSION" "${JPEG_TURBO_SHA256[@]}"
    install_bottle libimagequant "$LIBIMAGEQUANT_VERSION" "${LIBIMAGEQUANT_SHA256[@]}"
}

case "${1:-}" in
    lint) install_lint ;;
    sprites) install_sprites ;;
    xcodegen) install_bottle xcodegen "$XCODEGEN_VERSION" "${XCODEGEN_SHA256[@]}" ;;
    versions)
        echo "SwiftFormat $SWIFTFORMAT_VERSION"
        echo "SwiftLint $SWIFTLINT_VERSION"
        echo "pre-commit $PRE_COMMIT_VERSION"
        echo "libimagequant $LIBIMAGEQUANT_VERSION"
        echo "jpeg-turbo $JPEG_TURBO_VERSION"
        echo "XcodeGen $XCODEGEN_VERSION"
        ;;
    *)
        echo "usage: $0 lint|sprites|xcodegen|versions" >&2
        exit 2
        ;;
esac
