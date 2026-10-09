## Context

See proposal.md for why. Today's catalogs sit mostly in six files in `Packages/CityCore/Sources/CityCore/`:

- `Goods.swift`: `enum Good` (18 cases), the `GoodsCatalog` dictionary, and a `switch` for `basePrice`.
- `Building.swift`: `enum BuildingKind` (35 cases: 18 base, 8 luxury, 5 age signatures, 4 culture signatures), a custom `Codable` with two legacy aliases, the `BuildingCatalog` dictionary, a `cultureSpecs` helper that builds garden and producer specs from a template, and `culture`/`obsoletedBy`.
- `Production.swift`: `ProductionCatalog.recipe(for:)`. Some recipes are derived from `kind.culture.luxuryChain`.
- `Culture.swift`: four cultures with display name, blurb, `LuxuryChain` and per-tier names.
- `Research.swift`: ten techs with cost, prerequisites, unlocks, age, era, era gate and display name.
- `Age.swift`: five ages with start year and blurb.
- `AgeSignatures.swift` and `CultureSignatures.swift`: the nine signature buildings' catalog specs, `Culture.signature` and the age-ordered `BuildingKind.signatures` list. Their behaviour (ranges, bonuses, served luxuries) stays in Swift, but their specs have to become data because the generated `BuildingKind` must contain them.
- Value tables elsewhere that switch exhaustively over a content enum, so a new case breaks the build: `World.stockpileCapacity(for:)` (World.swift), `ResidentNames.list(for:)` (CityLife.swift), `Age.rivalResidentThreshold` (RivalSystem.swift), `BuildingKind.signatureCulture` (CultureSignatures.swift), `BuildTool.displayName` (CityUI) and `SpriteAnimation.operationalEntry` (CityRender2D). Behaviour switches such as the inspector's signature lines, `fuel` and `signatureReaches` already end in `default:`.

Constraints that shape the design:

- CityCore uses only Foundation and builds on Linux (`swift:6.0-jammy` in CI). The generated output must too, and the generator must build there as well.
- The simulation is deterministic and checked across platforms by `DeterminismFixture`. `Good.allCases` order drives caravans, supply, material cost and the rival market. `Culture.allCases` order drives rival setup. `Tech.allCases` and `Age.allCases` order drive research and age comparison. `BuildingKind.allCases` is iterated only by the sprite atlas preload, a set-building helper, the build palette (`BuildPaletteView.kinds`, which sets the palette button order) and the sprite catalog test. None of these affect simulation state.
- No new Homebrew tools. No third-party runtime dependencies; a build-time-only package is acceptable (D2).
- Every spec scenario needs a swift-testing test under `Packages/*/Tests`.

## Goals / Non-Goals

**Goals:**
- Content edits touch data files only. Adding a good, building or tech needs no Swift change unless it brings new behaviour.
- Keep type safety: content stays as Swift enums, and generated lookups are exhaustive `switch` statements. Hand-written code reads per-item values from the generated catalogs instead of keeping its own exhaustive table (D11), so a pack that adds an item compiles without Swift edits.
- Make the data easy to read for humans and for code generators, and easy to produce by script or LLM later.
- Group content by feature: one culture (its culture entry, goods, buildings and signature) lives in one pack file and can be added or removed as a unit.

**Non-Goals:**
- Loading data at runtime, hot reload or third-party mods. Packs are a source-layout tool; they are all compiled in.
- Full Kubernetes-style envelopes (`apiVersion`, `metadata`, `spec`). See D2a.
- Generating behaviour such as systems, placement rules or the shipyard's ship spawn.
- Moving signature behaviour, rivals, difficulty or goals in this change. Only the signature buildings' specs move.
- Driving the sprite catalog from game data. The existing `SpritesStyleCatalogTests` already derives its expected entries from `BuildingKind`, `Culture` and `Age` cases, so new content without art fails that test (D10).
- House tier needs as data. That is the follow-up change `tier-needs-data`; until it lands, tier needs stay in `HouseTier.needs`.

## Decisions

### D1. Generate committed Swift ahead of time, not at build time

Run `make gamedata` to write `Sources/CityCore/Generated/*.swift`, then commit the output. `make gamedata-check` regenerates into a temp directory and diffs the result against the committed files.

*Alternatives considered:*
- **SwiftPM build-tool plugin.** Runs on every build, so it never drifts. But the plugin runs in a sandbox, adds a plugin dependency to CityCore's `Package.swift`, behaves differently under xcodebuild and plain SwiftPM, makes the Linux container build slower, and hides the generated code from review and from IDE "jump to definition". Committed output lets reviewers see the real Swift diff next to the data diff.
- **Load JSON at runtime** with a `Bundle.module` resource. This loses enum exhaustiveness: `BuildingKind` would become a string wrapper. It also adds a failure path at launch and a decode step on Linux. It goes against the main goal.

### D2. YAML pack files with typed items

Content lives in pack files under `Packages/CityCore/GameData/packs/`. A manifest, `GameData/index.yaml`, lists the packs in load order:

```yaml
# yaml-language-server: $schema=./schema/index.schema.json
schemaVersion: 1
packs:
  - core                          # base goods, buildings and regular techs
  - cultures/northern-european
  - cultures/mediterranean
  - cultures/east-asian
  - cultures/middle-eastern
  - ages                          # ages, era techs, age signature buildings
```

A pack is one YAML document with an optional `defaults` block for anchors and an ordered `items` sequence. Each item has a `kind` (`Good`, `Building`, `Culture`, `Tech` or `Age`) and an `id`. The remaining fields depend on the kind:

```yaml
# yaml-language-server: $schema=../../schema/pack.schema.json
defaults:
  garden: &garden
    footprint: [2, 2]
    cost: 60
    buildTicks: 25
    materials: { wood: 2 }
    unlockedBy: cultivation
  producer: &producer
    footprint: [2, 2]
    cost: 120
    upkeep: 1
    buildTicks: 30
    materials: { wood: 3, planks: 3 }
    unlockedBy: cultivation

items:
  - kind: Culture
    id: mediterranean
    name: Mediterranean
    blurb: Whitewashed walls, terracotta roofs and bell towers.
    tiers: { peasants: Plebeians, citizens: Citizens, merchants: Patricians }
    luxury: { raw: grapes, good: wine, garden: vineyard, producer: winery }
    signature: forum

  - { kind: Good, id: grapes, name: Grapes, unit: baskets, basePrice: 3 }
  - { kind: Good, id: wine, name: Wine, unit: amphorae, basePrice: 16 }

  - kind: Building
    id: vineyard
    <<: *garden
    culture: mediterranean
    recipe: { outputs: { grapes: 1 }, cycleTicks: 40 }

  - kind: Building
    id: winery
    <<: *producer
    culture: mediterranean
    recipe: { inputs: { grapes: 2 }, outputs: { wine: 1 }, cycleTicks: 50 }

  # Spec: culture-signatures
  - kind: Building
    id: forum
    culture: mediterranean
    footprint: [3, 3]
    cost: 220
    upkeep: 2
    buildTicks: 40
    materials: { wood: 2, planks: 6 }
```

Rules that make packs self-contained:

- **References point from the new content to the existing content, never the other way.** A building names the tech that unlocks it (`unlockedBy`), and the generator builds `Tech.unlocks` as the inverse. That way a culture pack never has to edit `core.yaml`. Age signatures work the same way: an `Age` item names its `signature` building.
- References resolve across all packs after everything is loaded, so forward references (a core tech naming `age: medieval` before the `ages` pack loads) are fine.
- Anchors work within one pack because each pack is a single YAML document. Shared defaults are therefore per pack. That is enough for today's duplication: the four culture packs each carry their own `garden` and `producer` defaults, so one culture can be rebalanced without touching the others.

Why YAML: one field per line diffs cleanly, comments carry spec references, and anchors with merge keys replace copy-paste (D6).

The parser is **Yams**, pinned to an exact version in `GameDataGen/Package.swift` with `Package.resolved` committed. It is the repo's first third-party package, which is acceptable because it is build-time only: CityCore, the apps and the CLI never link it. Yams wraps libyaml and builds on Linux.

YAML quirks are contained by the decoder: every field decodes into a concrete Swift type, so a value such as `no` or `1.10` cannot silently become a bool or a float in a string field. The decoder rejects such mismatches, and the schema marks ids and names as `type: string`. Duplicate keys in one mapping are a parse error.

Merge keys: Yams' `YAMLDecoder` resolves aliases. Whether it also applies `<<:` when decoding into `Decodable` types is checked by the first spike test (task 1.2). If it does not, the generator parses to a `Yams.Node` tree, applies merge keys itself (keys written on the item win over merged ones, as in the YAML 1.1 merge spec), and decodes the resolved tree. Either way, the spec scenario "Shared defaults through anchors and merge keys" pins the behaviour.

Editor schema: one `pack.schema.json` with a `oneOf` over the five kinds, discriminated by `kind` through `if`/`then`. Errors in editors are a little vaguer than with one schema per file, but the generator's own messages name the pack, the item and the field.

*Alternatives considered:*
- **One file per catalog** (`goods.yaml`, `buildings.yaml` and so on). This was the previous draft. It is simpler, but a culture is spread over five files and cannot be added or removed as a unit.
- **JSON.** Foundation decodes it with no dependency, but it has no comments and no reuse, and its diffs are noisier.
- **TOML.** It also needs a third-party parser, has no anchors, and nested recipe maps are awkward to write in it.
- **Swift DSL** (data written as Swift literals). It needs no generator, but it is the status quo with extra steps and cannot be validated or produced by other tools.

### D2a. Light envelope, not Kubernetes-style documents

Items carry only `kind` and `id`. There is no `apiVersion`, `metadata` or `spec` nesting, and no `---` multi-document files.

*Alternative considered:* full k8s-style resources. They would add per-kind versioning, labels and annotations, and a familiar shape. They would cost four to five lines of boilerplate per item (about 300 lines for today's content), conversion code for versions nobody outside the repo consumes, and anchors, which do not reach across `---` documents. Data and generator always change in the same commit, so one repo-wide `schemaVersion` in the manifest is enough. If third-party packs ever arrive, the move to full envelopes is a mechanical rewrite.

### D3. Generator as its own package, `Packages/GameDataGen`

The generator is a SwiftPM package with a library target (`GameDataModel`, which decodes and validates), an executable target (`gamedata-gen`), and a test target. It depends on Foundation and Yams. CityCore does not depend on it. The dependency runs only one way, from the Makefile to the tool, so CityCore stays framework-free and dependency-free.

Putting it under `Packages/` rather than `Tools/` means `check-scenario-coverage.swift` picks up its tests without changes.

*Alternative:* a single-file script like `scripts/check-audio-manifest.swift`. A script cannot have unit tests for the validation rules the spec requires.

### D4. What is generated, and what stays hand-written

| Generated (`Generated/`) | Hand-written (stays) |
|---|---|
| `enum Good` cases, `GoodsCatalog.specs`, `Good.basePrice` | `Stockpile` |
| `enum BuildingKind` cases, the legacy-alias `Codable`, `BuildingCatalog.specs` (including the nine signature specs), `culture`, `obsoletedBy`, `displayName`, `storage` (replaces `World.stockpileCapacity`) | `Footprint`, `BuildingSpec`, `Building`, placement logic, signature ranges and bonuses, `signatureCulture` (derived from `Culture.signature`) |
| `ProductionCatalog.recipe(for:)` | `ProductionRecipe`, the production systems, the shipyard and monument side effects |
| `enum Culture` cases, `displayName`, `blurb`, `luxuryChain`, tier names, `signature`, `residentNames` (replaces `ResidentNames`' tables) | `LuxuryChain`, `HouseTier.needs(in:)`, served luxuries |
| `enum Tech` cases, `cost`, `prerequisites`, `unlocks` (inverse of `unlockedBy`), `age`, `era`, `eraGate`, `displayName` | `ResearchState`, `World.canChooseResearch`, `Comparable` |
| `enum Age` cases, `startYear`, `blurb`, `signature` (and from it `BuildingKind.signatures`), `rivalResidents` (replaces `rivalResidentThreshold`) | `next`, `Comparable`, `World.advanceAge` |

Generated lookups are exhaustive `switch` statements, not dictionaries. That keeps the missing-case compiler error and removes today's `preconditionFailure("… missing from catalog")` paths. `GoodsCatalog.specs` and `BuildingCatalog.specs` keep their public shape (`all`, `spec(for:)`) so callers do not change.

Generated files use the same type names, so the hand-written parts sit in extensions in the existing files.

### D5. Manifest order, then item order, is case order

Each enum's cases are emitted in load order: packs in manifest order, then items in file order. Keys inside a value are emitted sorted, for example the goods in `materials`. `Tech.unlocks` lists buildings in `BuildingKind` case order.

With the manifest above, this reproduces today's order exactly for `Good` (ten core goods, then raw and luxury per culture), `Culture`, `Tech` and `Age`. Those are the orders the simulation depends on.

`BuildingKind` order changes. Each culture's signature building moves next to its luxury buildings, and the age signatures move to the end. That is acceptable because nothing in the simulation depends on that order (see Context). It is visible in one place: the build palette lists buildings in `allCases` order, so culture signature buttons move next to their luxury buildings. `HUDFeedbackTests` covers the palette and is re-run in task 3.4. The migration parity test (D8) compares `BuildingKind` as a set, while the other four enums are compared in order. Task 3.4 re-checks this with an audit and the determinism fixtures. `Tech.unlocks[.cultivation]` keeps today's order, because filtering the new order to the eight luxury buildings gives the same sequence.

### D6. Derived content becomes data, shared through anchors

Today `cultureSpecs` builds eight garden and producer specs from two templates, and luxury recipes are derived from `luxuryChain`. In the data, each of these buildings becomes its own item in its culture's pack. It merges the pack's `garden` or `producer` defaults with `<<:` and can override any field. The generator sees fully merged items, so anchors never reach the Swift output. `Culture.luxuryBuildings` stays as hand-written code that derives its list from the generated `luxuryChain`.

*Alternative:* a custom `template:` field the generator expands, which would also work across packs. Rejected for now because YAML merge keys cover today's duplication with no generator code and with editor support. If cross-pack templates are ever needed, a `kind: Template` item can be added without changing existing packs.

### D7. Validation lives in the generator, not in a test

`GameDataModel.validate()` checks every rule in the spec ("Generator validates cross-references") and collects all errors before failing, so one run reports everything. JSON Schema covers structure in the editor. The generator re-checks structure itself, so it does not need a JSON Schema runtime. Swift's `Decodable` ignores unknown keys, so each item decoder compares `container.allKeys` with its `CodingKeys` and fails on anything extra. The merge key `<<` is resolved and removed before that comparison, and each pack's top-level `defaults` block is skipped. A test keeps schema and decoder in step by checking that each kind's required and allowed schema properties equal the decoder's keys.

### D8. Parity before deletion, against a recorded baseline

Migration happens in two steps (see Migration Plan). First, the generator emits into a temporary `GameDataParity` namespace while the hand-written catalogs are still in place. A parity test then compares every value field by field, including the tables listed in Context (`stockpileCapacity`, `ResidentNames`, `rivalResidentThreshold`, `signatureCulture`, `BuildTool` labels) and `BuildingKind.signatures` (today's stand-in for the new `Age.signature`). Only after that test passes are the hand-written tables removed and the generator switched to emit the real type names.

The parity test is a migration gate, not a lasting spec requirement. It is deleted together with the legacy tables in M3. From then on, every value change is visible as a diff of the committed `Generated/` files, which `gamedata-check` keeps in sync with the packs. A separate snapshot file would duplicate that.

Values alone do not prove unchanged behaviour, so M2 also records a **determinism baseline**: the output of `DeterminismFixture` at its default length and at 36000 ticks, run on unchanged `main`. CI today only compares macOS with Linux on the same commit, which cannot catch a behaviour change between commits. After M3, the fixture output must equal the recorded baseline byte for byte. The baseline lives in the change folder (`openspec/changes/game-data-codegen/baseline/`) and is archived with the change; turning it into a standing CI gate is out of scope.

### D9. `effect: code` marks buildings whose behaviour is in Swift

Many buildings do something a recipe cannot express: houses hold people, warehouses store goods, the library makes knowledge, the shipyard launches ships, the monument advances stages, and signatures apply bonuses. In the packs these declare `effect: code`. Such a building may have a recipe (the monument keeps its stage inputs) and may leave out recipe outputs, which replaces the earlier `outputs: {}` convention.

The generator uses the marker for one check: a building with no recipe that produces goods and no `effect: code` is inert and is rejected. In the plausibility run this flagged exactly the four generated buildings that did nothing.

*Alternative considered and rejected:* a generated `BuildingEffect` enum that hand-written CityCore must `switch` over exhaustively, so a new code-effect building would not compile until handled. Review showed it gives false assurance. Behaviour today dispatches through `BuildingKind` switches with `default:` branches (`signatureReaches`, `fuel`, `signatureCulture`), so the enum would be a parallel list that `case .x: break` satisfies, and a test that every case has a handler would only restate what the compiler checks.

### D10. Completeness: art and demand

Two kinds of content validate but do not work in the game:

- **Art.** `SpritesStyleCatalogTests` (CityRender2D) already builds its expected entries from `BuildingKind.allCases`, the culture variants and the age house looks, and requires all four orientations for shore buildings. Once these enums are generated, a pack that adds a building, culture or age without catalog entries fails that test. The generator does not repeat the check: a filename rule such as `building-<id>-*.md` would let an id `tea` pass because `building-tea-garden.md` exists.
- **Demand (CityCore test).** Every `Good` must be a recipe input, a construction material, a culture luxury, or a need of some `HouseTier`. The need lists live in Swift until `tier-needs-data` lands, so this check runs as a swift-testing test over the generated catalogs. When tier needs become data, the check moves into the generator.

Building display names come from an optional `name` on each building, which defaults to the id title-cased. For parity, every building gets the label `BuildTool.displayName` shows today ("Lumberjack", "Town Ctr."), and `BuildTool` then reads `BuildingKind.displayName`.

### D11. Hand-written code reads values from the catalogs

A pack can only add an item without Swift edits if no hand-written code keeps its own exhaustive table over a content enum. Each table in Context is handled one of two ways:

| Table | Becomes |
|---|---|
| `World.stockpileCapacity(for:)` | `storage` on each building (omitted means no stockpile) |
| `ResidentNames.list(for:)` | `residentNames` on each culture |
| `Age.rivalResidentThreshold` | `rivalResidents` on each age |
| `BuildingKind.signatureCulture` | derived from the generated `Culture.signature` |
| `BuildTool.displayName` building labels | `name` on each building (D10) |
| `SpriteAnimation.operationalEntry` | stays in CityRender2D (animation timing is art, not content) but gains a `default:` that gives the two-frame idle loop most buildings use today |

Behaviour switches that already end in `default:` stay as they are. A new signature building therefore compiles and has no bonus until someone writes one. The inert check (D9) does not catch this, because the building declares `effect: code` on purpose. M4 adds a CI step that generates with a fixture pack (a culture, a building and an age that do not exist in the game) and builds CityCore, CityUI and CityRender2D, so the "no Swift edits" claim stays true.

### D12. Vetted agent skills for pin-pointed content changes

Content changes will often be made by agents. The plausibility run showed that agents working from the format reference alone produce valid but unplayable content, and that their edits drift: an anchor change silently rebalances several buildings. Four project skills under `.claude/skills/` encode the procedures (drafts in `skills/`):

| Skill | Scope |
|---|---|
| `gamedata-tune` | Change existing values. Override on the item rather than the shared anchor unless every user of the anchor is named. |
| `gamedata-add` | Add goods, buildings or techs to an existing feature: pack choice, outward references, consumer, `effect`, art follow-up. |
| `gamedata-culture` | A whole culture pack, following an existing one's shape, with a checklist of names, art and Swift follow-ups. |
| `gamedata-review` | Read-only plausibility review of a content diff, distilled from the review prompt that found the dead-end goods. |

Every skill except review ends the same way: regenerate, then compare the **semantic diff** with what was asked. `gamedata-gen diff <ref>` loads both revisions, resolves merges, and prints value-level changes (`Building sawmill: cost 120 → 130`), additions and removals. It ignores formatting and comments. That turns "the edit was pin-pointed" from a judgement into a check: for a tune, the semantic diff must equal the change written down before editing.

**Vetting.** A skill lands only with an eval suite in `.claude/skills/<name>/evals/`:

- `gamedata-tune` and `gamedata-add`: cases pair a prompt with the expected semantic diff (exact for tune; for add, only additions inside the named pack plus derived unlocks).
- `gamedata-culture`: one case per culture brief; pass means the generator validates, the diff touches only the new pack and the manifest, and the checklist items are present.
- `gamedata-review`: the five packs from the plausibility run are seeded cases, with the reviewer's blockers as expected findings.

`make skills-eval` runs each case three times with Claude Haiku, the weakest model we expect to drive the skills, in a scratch worktree with the hooks (D13) enabled. A skill passes when every run of every case meets its expectation. The suite runs before a skill lands and whenever the pack format, the generator or the skill changes; the result goes in the PR description. It does not run in CI, because every run costs model tokens.

*Alternatives considered:* one general "edit game data" skill (rejected: one intent per skill keeps instructions short enough for a small model to follow); relying on the format reference alone (rejected: that is what the plausibility run measured).

### D13. Hooks validate agent writes as they happen

`gamedata-check` in pre-commit catches mistakes at commit time, which for an agent is many steps after the bad edit. Two Claude Code hooks in a committed `.claude/settings.json` move the check to the edit itself:

- **PreToolUse** on `Edit|Write|MultiEdit`: a write under `Sources/CityCore/Generated/` is blocked (exit 2) with "edit the pack under `GameData/`, then run `make gamedata`".
- **PostToolUse** on the same tools: after a write under `GameData/`, the packs are validated. Errors go back to the agent through exit status 2 with pack, item and field, so it corrects the edit on its next step. Validation only; the hook never regenerates or rewrites files behind the agent's back.

Both hooks call `scripts/gamedata-hook.sh`, which returns at once for any other path, so ordinary edits pay nothing. For game-data edits it runs a release build of `gamedata-gen` (built once, then reused) with a `hook` subcommand that parses Claude Code's hook JSON from stdin. That avoids `jq` and Python, which the rest of the tooling does not require. The hook behaviour is unit-tested through that subcommand.

*Alternatives considered:* validating in the skills only (rejected: hooks also cover agents that do not load a skill, and humans using Claude Code); auto-regenerating in the hook (rejected: writes the agent did not make are confusing in its context and in review).

### Determinism

The generated output is pure value tables. The same values the hand-written code returns, in the same `allCases` order, give the same `World` evolution tick for tick. D5 locks the order, D8 locks the values, and `DeterminismFixture` on macOS and Linux catches anything those two miss. The generator itself is deterministic: it reads packs in manifest order and never lists directories to find them, sorts keys, writes with `\n` line endings, and includes no timestamps. That makes `gamedata-check` reliable on both platforms.

Determinism holds for identical content, not across content changes. Adding a culture appends to `Culture.allCases`, which rival setup picks from, so the same seed plays out differently once a pack is added. That is intended. A change that adds or reorders content regenerates the `DeterminismFixture` baselines in the same PR and says so in the description. A change that only refactors must leave them byte-identical.

### Framework-free invariant

Generated files import only `Foundation` (and need even less). `check-no-apple-ui-imports.sh` already scans everything under `Sources/CityCore`, including `Generated/`. The generator package is never a dependency of CityCore.

## Risks / Trade-offs

- [Contributors edit the generated Swift by hand] → Each generated file starts with a `// GENERATED by gamedata-gen — edit Packages/CityCore/GameData/packs/` banner, and `gamedata-check` in pre-commit and CI rejects the edit.
- [Reordering packs in the manifest, or items in a pack, silently changes `allCases`] → During migration the parity test checks the order of `Good`, `Culture`, `Tech` and `Age`; afterwards any reorder shows up as a diff of the committed `Generated/` files and of the determinism fixtures. The spec scenario "Case order follows manifest and item order" is tested. `DeterminismFixture` diffs catch any behaviour change.
- [A pack file exists but is missing from the manifest, so its content silently drops out] → The generator fails on any `.yaml` under `packs/` that the manifest does not list, and on any manifest entry with no file.
- [Shared defaults are per pack, so the four culture packs repeat the same garden and producer numbers] → Accepted. Each culture can be balanced on its own, and the parity test shows when they drift apart. A cross-pack `Template` kind stays possible (D6).
- [Renaming an `id` breaks old saves] → The save fixtures under `CityPersistence/Tests/Fixtures` already fail to decode when an id disappears, and a renamed id keeps old saves loading by moving its old value into `legacyIds`.
- [YAML's implicit typing (`no` → false, `1.10` → 1.1)] → Strict typed decoding rejects the mismatch, ids are strings in the schema, and a test covers a quoted-vs-unquoted id.
- [Merge-key overrides are easy to misread: which value wins?] → Keys written in the entry always win over merged ones. Generated Swift shows the resolved values, so the review diff shows the effect.
- [First third-party package; supply-chain and toolchain risk] → Build-time only, exact version pin, `Package.resolved` committed, Dependabot watches it. If Yams ever blocks a toolchain upgrade, the model layer is format-independent and JSON input can be swapped in.
- [Xcode has no YAML schema support] → VS Code and other LSP editors get schema validation; everyone gets the generator's error messages, which name the file and entry.
- [The generator's own tests never run in CI, because the package list in `ci.yml` is hard-coded] → M4 adds `GameDataGen` to the macOS package loop and the Linux job.
- [The generator becomes a second codebase to maintain] → Keep it small: a decoder, a validator and a string emitter, with no templating engine. Covered by its own tests.
- [SwiftLint or SwiftFormat flag generated code] → `Generated/` is excluded from SwiftFormat and from SwiftLint's `cyclomatic_complexity`, `file_length` and `line_length` rules. Writing format-clean output by hand is fragile, and SwiftFormat is not installed in the Linux container, so `gamedata-check` cannot depend on it.

## Migration Plan

1. Land `GameDataGen` with validation and tests. It is not wired into CityCore yet.
2. Record the determinism baseline on unchanged `main`. Write the manifest and packs by transcribing today's values. Generate into a `GameDataParity` namespace and add the parity test. Behaviour does not change.
3. Switch the generator to the real type names, delete the hand-written tables and the parity test, and move the leftover behaviour into extensions. Run the full test suite and compare the determinism fixtures with the baseline.
4. Wire up `gamedata-check`, the generator's tests and the fixture-pack build in the Makefile, pre-commit and CI.
5. Add the semantic diff, the hooks and the four skills, and land each skill only once its eval suite passes.

Each step is its own PR. To roll back step 3, revert it: the hand-written tables come back and the data files stay as unused input.

## Open Questions

- Should rivals, difficulty, goals and signature behaviour parameters follow in a later change? Probably yes, once this pattern has proved itself.
- Should a balance lint (price bands, value per tick, input/output value ratio) run as generator warnings? The plausibility run found one out-of-band chain. This can be added later without changing the format.
- Should the manifest's `schemaVersion` gain a migration step when it is first bumped? This can wait until a format change needs it.
