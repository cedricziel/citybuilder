#!/usr/bin/env bash
# Runs the PlayerBot release sweeps one after another against a snapshot of
# Packages/CityCore: solvency with the market control, mid-game pacing with
# retention, then rival viability. See scripts/sweeps/README.md.
#
# Usage: scripts/sweeps/run-release-sweeps.sh <package-snapshot-dir> <out-dir>
set -uo pipefail

if [ $# -ne 2 ]; then
    echo "usage: $0 <package-snapshot-dir> <out-dir>" >&2
    exit 64
fi

package=$1
out=$2
if [ ! -f "$package/Package.swift" ]; then
    echo "error: $package has no Package.swift; pass a copy of Packages/CityCore" >&2
    exit 66
fi
mkdir -p "$out"
rm -f "$out/DONE"

solvency_filter="scenarioMarketTradingTownsStaySolventAcrossSeeds|scenarioTheMarketDoesNotMakeTownsWorseOff"
solvency_filter+="|scenarioGuidedHardStartStaysSolventAndGrows|scenarioUnguidedHardStartGoesBankrupt"
solvency_filter+="|scenarioOrderKitTownsStaySolventAcrossSeeds|scenarioOrderKitFillsHalfOfWhatResolves"
solvency_filter+="|scenarioGuidedHardStartWithOrdersStaysSolventAndGrows|scenarioTheMarketDoesNotMakeOrderTownsWorseOff"

statuses=()

# sweep <name> <line-pattern> <filter> [VAR=value ...]
# Writes the whole test log to <name>.log and the sweep lines to <name>.txt.
sweep() {
    local name=$1 lines=$2 filter=$3
    shift 3
    echo "==> $name ($(date '+%H:%M:%S'))"
    local status=0
    env RIVAL_SWEEP=1 "$@" nice -n 10 xcrun swift test -c release -Xswiftc -enable-testing \
        --package-path "$package" --filter "$filter" > "$out/$name.log" 2>&1 || status=$?
    grep -E "$lines" "$out/$name.log" > "$out/$name.txt"
    echo "    exit $status, $(wc -l < "$out/$name.txt" | tr -d ' ') sweep lines"
    statuses+=("$name=$status")
}

sweep solvency '^(SOLVENCY|GUIDE)_SWEEP' "$solvency_filter"
sweep pacing '^PACING_SWEEP' midGamePacingAcrossSeeds PACING_RETENTION=1
sweep rivals '^RIVAL_SWEEP' scenarioRivalsAreViableAcrossSeeds

printf '%s\n' "${statuses[@]}" > "$out/DONE"
echo "==> done: ${statuses[*]}"
