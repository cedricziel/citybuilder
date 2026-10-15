#!/usr/bin/env bash
# Reproduces issue #90: `make gamedata-check` failing to check out Yams.
# Each scenario runs the check in scratch checkouts holding only the
# generator, the game data, the Makefile and scripts/, and exits non-zero
# when any run fails.
#
#   scripts/repro-gamedata-check.sh race [N]
#       N fresh checkouts (default 3) resolve Yams from the shared SwiftPM
#       cache at the same moment.
#   scripts/repro-gamedata-check.sh damaged-mirror
#       A checkout whose package-local Yams mirror lost its objects, as an
#       interrupted resolve (a killed hook, a full disk) leaves it. Without
#       a retry, every later build in that checkout fails.
set -uo pipefail

root=$(cd "$(dirname "$0")/.." && pwd)
scenario=${1:-race}
scratch=$(mktemp -d "${TMPDIR:-/tmp}/gamedata-check.XXXXXX")
trap 'rm -rf "$scratch"' EXIT

checkout() { # dir
    mkdir -p "$1/Packages/CityCore/Sources/CityCore"
    rsync -a --exclude .build --exclude .swiftpm "$root/Packages/GameDataGen" "$1/Packages/"
    rsync -a "$root/Packages/CityCore/GameData" "$1/Packages/CityCore/"
    rsync -a "$root/Packages/CityCore/Sources/CityCore/Generated" "$1/Packages/CityCore/Sources/CityCore/"
    cp "$root/Makefile" "$1/"
    rsync -a "$root/scripts" "$1/"
}

report() { # count
    local failed=0
    for i in $(seq "$1"); do
        local status
        status=$(cat "$scratch/$i.status")
        echo "checkout $i: exit $status"
        if [ "$status" != 0 ]; then
            failed=$((failed + 1))
            sed 's/^/    /' "$scratch/$i.log" | grep -v '^    \[' | tail -6
        fi
    done
    echo "$failed of $1 failed"
    [ "$failed" -eq 0 ]
}

case "$scenario" in
    race)
        count=${2:-3}
        for i in $(seq "$count"); do checkout "$scratch/$i"; done
        for i in $(seq "$count"); do
            (cd "$scratch/$i" && make gamedata-check >"$scratch/$i.log" 2>&1; echo $? >"$scratch/$i.status") &
        done
        wait
        report "$count"
        ;;
    damaged-mirror)
        checkout "$scratch/1"
        cd "$scratch/1" || exit 1
        make gamedata-check >/dev/null 2>&1 || { echo "the first, clean check failed" >&2; exit 1; }
        rm -f Packages/GameDataGen/.build/repositories/Yams-*/objects/pack/*
        rm -rf Packages/GameDataGen/.build/checkouts
        make gamedata-check >"$scratch/1.log" 2>&1
        echo $? >"$scratch/1.status"
        report 1
        ;;
    *)
        echo "usage: $0 race [N] | damaged-mirror" >&2
        exit 64
        ;;
esac
