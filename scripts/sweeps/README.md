# Release sweeps

`run-release-sweeps.sh` runs the PlayerBot balance sweeps on the dev Mac, one after another, against a snapshot of `Packages/CityCore`.

## One sweep at a time

A full run takes hours and uses every core. Two runs at once slow each other down and starve other agents. Agents ask the orchestrator for the single sweep slot first and start a full run only once they have it. Smoke runs with `SWEEP_SEEDS=1` don't need the slot.

## Run it

Snapshot the package, so you can keep editing the worktree during the run:

```sh
rsync -a --exclude .build Packages/CityCore/ <dir>/CityCore/
scripts/sweeps/run-release-sweeps.sh <dir>/CityCore <out-dir>
```

The build goes into the snapshot's own `.build`. Run the script in a terminal or as a background job, and wait for `<out-dir>/DONE`.

Each sweep runs `RIVAL_SWEEP=1 nice -n 10 xcrun swift test -c release -Xswiftc -enable-testing --package-path <snapshot> --filter ...`. It uses `xcrun swift` because the `swift` on `PATH` on the dev Mac is a swiftly toolchain that doesn't match the Xcode SDK.

| Sweep | Tests | Lines |
|---|---|---|
| `solvency` | the solvency tests, the no-market control and the order-kit variants (the same filter as the `rival-sweep` workflow) | `SOLVENCY_SWEEP`, `GUIDE_SWEEP` |
| `pacing` | `midGamePacingAcrossSeeds` with `PACING_RETENTION=1`: 180 games (seeds 0–9 × 3 difficulties × 2 layouts × 3 bot orders, market on), each to year 10 | `PACING_SWEEP` |
| `rivals` | `scenarioRivalsAreViableAcrossSeeds` | `RIVAL_SWEEP` (60 lines) |

Each `PACING_SWEEP` line has `merchantsAtTen`, `heldShare` (the share of bot turns in years 8–10 with 20 or more merchants) and `meanLate` (the mean merchant count over those turns).

## Output

For each sweep, `<out-dir>` gets `<name>.log` (the full test output) and `<name>.txt` (only the sweep lines). At the end the script writes `DONE` with one exit status per sweep, such as `solvency=0`. It deletes `DONE` at the start, so a `DONE` file means the run finished.

A failing sweep doesn't stop the next one. A non-zero status means a balance assertion failed or the build broke; the `.log` says which.

## Options

Other environment variables pass through to the tests:

- `SWEEP_SEEDS=N` keeps the first N seeds of every sweep, and of the 30-seed market controls. `SWEEP_SEEDS=1` smoke-tests the script in a few minutes.
- Pacing only: `PACING_ORDERS=1`, `PACING_FULL=1`, `PACING_DIFFICULTIES=normal`, `PACING_CAREFUL_ONLY=1`.

## Not included

The events sweeps (`guidedHardStartWithFireSeason`, `forcedFireFirstHour`; lines `GUIDE_SWEEP events` and `FIRE_SWEEP`) aren't in the script. Run them by hand with the same command and their `--filter`.

## In CI

`.github/workflows/rival-sweep.yml` runs the same tests weekly. It also sets `PACING_ORDERS=1` for pacing.
