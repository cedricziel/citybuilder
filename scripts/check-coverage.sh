#!/usr/bin/env bash
# scripts/check-coverage.sh
#
# Enforces design D13 coverage floors:
#   CityCore line coverage   >= 80%
#   CityCore branch coverage >= 70%   (informational; llvm-cov line is the
#                                       primary gate — branch coverage in
#                                       Swift/LLVM is sometimes noisy)
#
# Also runs diff-cover (if installed) to fail when added/changed lines in
# CityCore in this branch lack coverage. Compare-against branch defaults
# to `main`; override via COVERAGE_BASE_REF.
#
# Usage:
#   scripts/check-coverage.sh
#
# Env vars:
#   LINE_COV_MIN     default 80   (percent)
#   BRANCH_COV_MIN   default 70   (percent; soft warning if missing)
#   COVERAGE_BASE_REF  default main
#   COVERAGE_STRICT  default 0    set 1 to fail when diff-cover not installed
#   COVERAGE_REUSE   default 0    set 1 to reuse the profdata of a test run
#                                 that already used --enable-code-coverage
set -euo pipefail

LINE_COV_MIN=${LINE_COV_MIN:-80}
BRANCH_COV_MIN=${BRANCH_COV_MIN:-70}
BASE_REF=${COVERAGE_BASE_REF:-main}
STRICT=${COVERAGE_STRICT:-0}

PKG=Packages/CityCore
BUILD_DIR="$PKG/.build"
COVERAGE_DIR=coverage
mkdir -p "$COVERAGE_DIR"

if [ "${COVERAGE_REUSE:-0}" != "1" ]; then
    echo "==> Running CityCore tests with coverage instrumentation"
    swift test --package-path "$PKG" --enable-code-coverage > /dev/null
fi

# Find the .profdata and the test binary llvm-cov needs.
PROFDATA=$(find "$BUILD_DIR" -name "default.profdata" -path "*debug*" | head -1)
XCTEST_BUNDLE=$(find "$BUILD_DIR" -name "*.xctest" -path "*debug*" | head -1)
BIN_PATH=""
if [ -n "$XCTEST_BUNDLE" ]; then
    # On macOS the test binary is inside the .xctest bundle.
    BIN_PATH=$(find "$XCTEST_BUNDLE" -type f -perm +111 -not -name "*.dylib" | head -1)
fi
# Fallback: also accept a top-level Xcode test runner binary.
if [ -z "$BIN_PATH" ]; then
    BIN_PATH=$(find "$BUILD_DIR" -name "CityCorePackageTests" -type f -perm +111 | head -1)
fi

if [ -z "$PROFDATA" ] || [ -z "$BIN_PATH" ]; then
    echo "ERROR: could not locate profdata ($PROFDATA) or test binary ($BIN_PATH)" >&2
    exit 1
fi

LCOV_PATH="$COVERAGE_DIR/citycore.lcov"
echo "==> Exporting LCOV to $LCOV_PATH"
xcrun llvm-cov export \
    -format=lcov \
    -instr-profile "$PROFDATA" \
    "$BIN_PATH" \
    --ignore-filename-regex='\.build|Tests' > "$LCOV_PATH"

# ---- Aggregate line coverage from LCOV --------------------------------
# LCOV records: LH = lines hit, LF = lines found.
LF=$(grep -c '^DA:' "$LCOV_PATH" || true)
LH=$(awk -F'[:,]' '/^DA:/ && $3 > 0 {n++} END {print n+0}' "$LCOV_PATH")
if [ "$LF" = "0" ]; then
    LINE_PCT=0
else
    LINE_PCT=$(awk -v h="$LH" -v f="$LF" 'BEGIN {printf "%.1f", (h/f)*100}')
fi
echo "==> CityCore line coverage: $LINE_PCT% ($LH / $LF lines)"

# ---- Branch coverage --------------------------------------------------
BF=$(grep -c '^BRDA:' "$LCOV_PATH" || true)
BH=$(awk -F'[:,]' '/^BRDA:/ && $5 != "-" && $5 > 0 {n++} END {print n+0}' "$LCOV_PATH")
if [ "$BF" = "0" ]; then
    echo "==> CityCore branch coverage: n/a (no branches recorded yet)"
    BRANCH_PCT=100
else
    BRANCH_PCT=$(awk -v h="$BH" -v f="$BF" 'BEGIN {printf "%.1f", (h/f)*100}')
    echo "==> CityCore branch coverage: $BRANCH_PCT% ($BH / $BF branches)"
fi

# ---- Enforce floors ---------------------------------------------------
fail=0
if [ "$LF" = "0" ]; then
    echo "==> No instrumented executable lines in CityCore yet (declarative-only code) — skipping line floor"
else
    if awk -v p="$LINE_PCT" -v m="$LINE_COV_MIN" 'BEGIN {exit !(p < m)}'; then
        echo "FAIL: CityCore line coverage $LINE_PCT% < required $LINE_COV_MIN%" >&2
        fail=1
    fi
fi
if [ "$BF" != "0" ]; then
    if awk -v p="$BRANCH_PCT" -v m="$BRANCH_COV_MIN" 'BEGIN {exit !(p < m)}'; then
        echo "FAIL: CityCore branch coverage $BRANCH_PCT% < required $BRANCH_COV_MIN%" >&2
        fail=1
    fi
fi

# ---- diff-cover against base ref -------------------------------------
if command -v diff-cover >/dev/null 2>&1; then
    if git rev-parse --verify "$BASE_REF" >/dev/null 2>&1; then
        echo "==> diff-cover against $BASE_REF"
        if ! diff-cover "$LCOV_PATH" --compare-branch="$BASE_REF" --fail-under=100 \
            --include-untracked --src-roots Packages/CityCore/Sources; then
            echo "FAIL: changed lines in CityCore not covered by tests" >&2
            fail=1
        fi
    else
        echo "==> diff-cover: base ref '$BASE_REF' not found, skipping"
    fi
else
    msg="diff-cover not installed (pipx install diff-cover)"
    if [ "$STRICT" = "1" ]; then
        echo "FAIL: $msg" >&2
        fail=1
    else
        echo "==> $msg — skipping diff-cover (set COVERAGE_STRICT=1 to fail)"
    fi
fi

exit $fail
