## 1. Spec and guard test

- [x] 1.1 Write the proposal, design and `playtesting` spec; `openspec validate add-playtest-harness --strict`
- [x] 1.2 Tests-first: `PlaytestKitTests` for the scenarios in `specs/playtesting/spec.md`; confirm red
- [x] 1.3 Implement to green: the skill and the eight agent files

## 2. Verify the platform limits

- [x] 2.1 Apple TV: confirm the control tool drives a tvOS simulator and note the remote buttons it can send
- [x] 2.2 Mac: confirm a window-only capture of a launched process and note what cannot be exercised
- [x] 2.3 Create an SE-size simulator with `simctl create` and confirm the app launches on it

## 3. Dogfood

- [x] 3.1 Run a short newcomer session on iPhone portrait through the UI; save the report and screenshots under `playtests/`
- [x] 3.2 Run a short UI-auditor pass on one iPhone size; save the report and screenshots under `playtests/`
- [x] 3.3 Fix the gaps in the skill the two sessions found

## 4. Wrap-up

- [x] 4.1 `make lint && make format`, `/simplify`, `openspec validate add-playtest-harness --strict`
