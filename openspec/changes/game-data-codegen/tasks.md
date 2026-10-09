## 1. M1 — Generator package and validation

- [ ] 1.1 Tests-first: in `Packages/GameDataGen/Tests`, translate the scenarios "Unknown good in a recipe is rejected", "Unknown house tier is rejected", "Tech prerequisite cycle is rejected", "Duplicate identifier is rejected", "Unlisted pack file is rejected", "Unknown field is rejected", "Inert building is rejected", "Two runs produce identical output", "Case order follows manifest and item order", "Shared defaults through anchors and merge keys", "Adding a culture pack adds the whole culture" and "Reference to a later pack resolves" into failing swift-testing tests that use small inline fixture packs. Confirm red.
- [ ] 1.2 Scaffold `Packages/GameDataGen` (swift-tools 6.0) with targets `GameDataModel` (library), `gamedata-gen` (executable) and `GameDataGenTests`. Add Yams pinned to an exact version and commit `Package.resolved`. Check that it builds with `xcrun swift build` and in the `swift:6.0-jammy` container. Spike: find out whether `YAMLDecoder` applies `<<:` merge keys, and record the result in design.md D2.
- [ ] 1.3 Implement to green: decode the manifest and packs (`schemaVersion`, ordered `packs`; per pack an optional `defaults` block and ordered `items` dispatched on `kind`). `Decodable` ignores unknown keys, so each item decoder compares `container.allKeys` with its `CodingKeys` and fails on extras; resolve and strip `<<` first (on the `Yams.Node` tree if the spike showed Yams does not apply merge keys). Reject unknown kinds and type mismatches (`no`, `1.10` in string fields).
- [ ] 1.4 Implement to green: resolve references across all packs after loading, build `Tech.unlocks` from `Building.unlockedBy`, and validate while collecting every error (duplicate ids per kind, unknown goods/buildings/techs/ages/house tiers, prerequisite cycles, broken luxury chains or signatures, pack files missing from the manifest, manifest entries without a file, inert buildings with no producing recipe and no `effect: code`). Each error names the pack, the item and the reference.
- [ ] 1.5 Implement to green: a deterministic Swift emitter (entry order for cases, sorted map keys, `\n` endings, generated-file banner, `BuildingKind.displayName` and `storage`, `Culture.residentNames`, `Age.rivalResidents`), and a CLI that writes into an output directory only when validation passes.
- [ ] 1.6 Refactor under a green bar. Run `swiftformat` and `swiftlint --strict` on the generator's own sources.
- [ ] 1.7 Verify `make test-scenarios` is clean for this milestone's scenarios.

## 2. M2 — Baseline, packs and parity

- [ ] 2.1 Record the determinism baseline on unchanged `main`: run `DeterminismFixture` at its default length and at 36000 ticks, and commit both outputs under `openspec/changes/game-data-codegen/baseline/`.
- [ ] 2.2 Tests-first: add the scenario "Schema and decoder agree" in `GameDataGenTests`, and a migration-only parity test in `CityCoreTests` (not a spec scenario; it is deleted in 3.3). The parity test compares a `GameDataParity` namespace field by field against today's `GoodsCatalog`, `Good.basePrice`, `BuildingCatalog` (including the signature specs), `ProductionCatalog`, `Culture`, `Tech`, `Age`, `World.stockpileCapacity`, `ResidentNames`, `Age.rivalResidentThreshold`, `BuildingKind.signatureCulture`, `BuildingKind.signatures` (the stand-in for the new `Age.signature`) and the `BuildTool` building labels. It checks case order for `Good`, `Culture`, `Tech` and `Age` and compares `BuildingKind` as a set. Confirm red.
- [ ] 2.3 Write `GameData/index.yaml` with the pack order from design D2, and `packs/core.yaml` with the ten base goods in today's order, the base buildings (house through shipyard, with `legacyIds` for `lumberjack-hut` and `town-center`, placement rules, recipes, `storage`, `obsoletedBy`, `unlockedBy`, `name` from today's `BuildTool` labels, and `effect: code` on house, warehouse, road, town center, library, port and shipyard) and the six regular techs.
- [ ] 2.4 Write the four `packs/cultures/*.yaml`: culture (name, blurb, tier names, luxury chain, signature, resident names), raw and luxury good, garden and producer through the pack's `defaults` anchors, and the signature building (`effect: code`). Carry today's doc comments over as YAML comments.
- [ ] 2.5 Write `packs/ages.yaml`: the five ages (start year, blurb, signature, rival residents), the four era techs (cost, prerequisites, era, era gate) and the five age signature buildings (`effect: code`; the monument keeps its stage recipe without outputs).
- [ ] 2.6 Write `index.schema.json` and `pack.schema.json` (one `if kind … then` branch per kind) under `GameData/schema/`, and make "Schema and decoder agree" pass.
- [ ] 2.7 Implement to green: add an emitter mode that writes into a `GameDataParity` namespace, generate it into CityCore, and make the parity test pass.
- [ ] 2.8 Refactor under a green bar.
- [ ] 2.9 Verify `make test-scenarios` is clean for this milestone's scenarios.

## 3. M3 — Switch CityCore to generated catalogs

- [ ] 3.1 Tests-first: add the scenarios "Every catalog entry comes from the packs" (a `GameDataGenTests` test that generates from the committed packs and checks that no Swift file outside `Generated/` declares `Good`, `BuildingKind`, `Culture`, `Tech` or `Age` cases), "Legacy building identifiers still decode" and "Every good has a consumer" (both in `CityCoreTests`, over the generated types). Confirm red.
- [ ] 3.2 Implement to green: emit the real type names (`Good`, `BuildingKind`, `Culture`, `Tech`, `Age`, `GoodsCatalog`, `BuildingCatalog`, `ProductionCatalog`) into `Sources/CityCore/Generated/`, using exhaustive `switch` lookups.
- [ ] 3.3 Delete the hand-written tables (`signatureSpecs`, `cultureSignatureSpecs`, `Culture.signature`, `BuildingKind.signatures`, `World.stockpileCapacity`'s switch, `ResidentNames`' lists, `Age.rivalResidentThreshold`'s switch) and point their callers at the generated values. Derive `signatureCulture` from `Culture.signature`. Move the remaining behaviour into extensions. Remove the `GameDataParity` namespace and the parity test.
- [ ] 3.4 Give `SpriteAnimation.operationalEntry` (CityRender2D) a `default:` branch with today's two-frame idle loop, keeping the explicit `nil` cases. Replace the building-name `switch` in `CityUI/BuildTool.swift` with `BuildingKind.displayName`.
- [ ] 3.5 Implement to green: the good-consumer test over recipes, materials, luxuries and `HouseTier.needs`.
- [ ] 3.6 Audit every `BuildingKind.allCases` use (sprite atlas preload, `workshops`, `BuildPaletteView.kinds`, `SpritesStyleCatalogTests`) to confirm none affects simulation state. Run every package's tests (`make test`), including `HUDFeedbackTests` for the new palette order and the CityPersistence save fixtures. Run `DeterminismFixture` at both lengths and confirm the output equals the M2 baseline byte for byte.
- [ ] 3.7 Exclude `Generated/` from SwiftFormat and from SwiftLint's `cyclomatic_complexity`, `file_length` and `line_length` rules. Confirm `make lint` and `make test-citycore-framework-free` pass.
- [ ] 3.8 Refactor under a green bar.
- [ ] 3.9 Verify `make test-scenarios` is clean for this milestone's scenarios.

## 4. M4 — Drift check in tooling and CI

- [ ] 4.1 Tests-first: translate "Stale generated output fails the check" and "Up-to-date output passes the check" into failing tests for a `check` mode of `gamedata-gen` (regenerate into a temp directory and diff). Confirm red.
- [ ] 4.2 Implement to green: a `--check` flag that exits non-zero and names each file that differs, was added or was removed.
- [ ] 4.3 Add Makefile targets `gamedata` (regenerate) and `gamedata-check`, and add them to `make help`.
- [ ] 4.4 Add a pre-commit hook that runs `make gamedata-check` when files under `GameData/` or `Generated/` are staged.
- [ ] 4.5 In `.github/workflows/ci.yml`: add `GameDataGen` to the macOS package test loop and the Linux job, and add a `gamedata-check` step to both. Add a `swift` ecosystem entry for `Packages/GameDataGen` in `.github/dependabot.yml`.
- [ ] 4.6 Add a macOS CI step that generates with a fixture pack (a culture, a building and an age that do not exist in the game, placed under `Packages/GameDataGen/Tests/Fixtures/`) into a scratch copy and builds CityCore, CityUI and CityRender2D, proving that a pack needs no Swift edits to compile.
- [ ] 4.7 Document the workflow (add or edit a pack → `make gamedata` → commit both; how the manifest orders cases; `effect: code`; editor schema setup; regenerating determinism baselines when content changes) in the README's contributor section through the technical-writer agent.
- [ ] 4.8 Refactor under a green bar.
- [ ] 4.9 Verify `make test-scenarios` is clean for all `game-data-catalog` scenarios, and run `openspec validate game-data-codegen --strict`.

## 5. M5 — Agent tooling: semantic diff, hooks and vetted skills

- [ ] 5.1 Tests-first: translate "Value change is listed once", "Anchor change lists every affected item", "Invalid pack edit is reported to the agent", "Hand edit of generated code is blocked" and "Unrelated edit passes through" into failing `GameDataGenTests` (the hook cases feed hook JSON to the `hook` subcommand). Confirm red.
- [ ] 5.2 Implement to green: `gamedata-gen diff <ref>` (load both revisions through `git show`, resolve merges, print value-level changes, additions and removals in load order).
- [ ] 5.3 Implement to green: `gamedata-gen hook pre|post`, then land `scripts/gamedata-hook.sh` and the hook entries in a committed `.claude/settings.json` from the drafts in `hooks/`. Check by hand in a Claude Code session that an invalid edit is reported and an edit to `Generated/` is blocked.
- [ ] 5.4 Add `make skills-eval`: for each skill's `evals/` cases, run three headless Claude Haiku sessions in a scratch worktree with the hooks enabled, and grade each run (generator validates, `gamedata-check` passes, semantic diff matches the expectation; review cases must report the seeded blockers).
- [ ] 5.5 Land `gamedata-tune` under `.claude/skills/` with at least five eval cases (single field, item overriding an anchor, anchor change naming every user, vague request that must stop for confirmation, value outside the packs that must be refused). Iterate until `make skills-eval` passes.
- [ ] 5.6 Land `gamedata-add` with at least four eval cases (good plus producer in `core`, culture-only building, good with no possible consumer that must stop, building needing `effect: code`). Iterate until it passes.
- [ ] 5.7 Land `gamedata-culture` with two culture briefs as eval cases. Iterate until it passes.
- [ ] 5.8 Land `gamedata-review` with the five plausibility-run packs as seeded cases and the reviewer's blockers as expected findings. Iterate until it passes.
- [ ] 5.9 Refactor under a green bar. Run the `plugin-dev:skill-reviewer` agent over the four skills and apply its findings.
- [ ] 5.10 Verify `make test-scenarios` is clean for all `game-data-catalog` scenarios, and run `openspec validate game-data-codegen --strict`.
