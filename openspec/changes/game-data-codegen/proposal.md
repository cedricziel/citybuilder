## Why

Game content is hardcoded in Swift. Goods, buildings, production recipes, cultures, techs and ages live as enum cases spread over 20+ `switch` statements in `CityCore`. Adding one building touches `Building.swift`, `Production.swift`, `Research.swift` and sometimes `Culture.swift`. Balancing a number means hunting for it in Swift code. Content cannot be reviewed, diffed or generated as data. Moving it into declarative data files, and generating the Swift from those files, keeps the compiler checks we have today and gives content one place to live.

## What Changes

- Add YAML content packs under `Packages/CityCore/GameData/packs/`, loaded in the order listed by a manifest (`GameData/index.yaml`). Each pack holds typed items (`kind: Good | Building | Culture | Tech | Age`, plus an `id`), so one feature lives in one file. For example, `cultures/mediterranean.yaml` holds the culture, grapes and wine, the vineyard, the winery and the forum. References point from new content to existing content (a building names the tech that unlocks it), so adding a culture means adding one pack. YAML diffs line by line, allows comments, and shares defaults within a pack through anchors and merge keys. JSON Schemas give editor validation and autocomplete.
- Add a build-time generator (`Packages/GameDataGen`, a Swift package that uses Foundation and Yams). It validates the packs, checking references across packs, recipe goods, tech prerequisite cycles, unique ids, and that the manifest and pack files match. It then writes deterministic Swift into `Packages/CityCore/Sources/CityCore/Generated/`.
- The generated code replaces the hand-written enums and catalog tables: `Good`, `GoodsCatalog`, `Good.basePrice`, `BuildingKind`, `BuildingCatalog`, `ProductionCatalog`, the `Culture` data properties, `Tech` data properties, `BuildingKind.culture` and `obsoletedBy`, the `Age` data properties, and the specs of the nine signature buildings (their behaviour stays in Swift). Value tables elsewhere that switch over these enums move into the packs too: stockpile capacity (`storage`), resident names (`residentNames`), rival age thresholds (`rivalResidents`) and the palette labels (`name`). That way a pack that adds an item compiles without Swift edits; a CI step builds with a fixture pack to keep it that way.
- Behaviour stays hand-written in Swift: systems, `World` extensions, special-case production effects (shipyard, monument), age and research rules.
- Buildings whose behaviour lives in Swift declare `effect: code`. A building with neither a producing recipe nor that marker is rejected as inert. New code-effect buildings compile but do nothing until their behaviour is written; that stays a deliberate Swift step.
- Every good needs a consumer: a recipe input, material, luxury or tier need. A CityCore test checks this until tier needs become data. Missing art is already caught by the existing sprite catalog test, which derives its expected entries from the generated enums.
- The build palette order changes: it follows `BuildingKind` order, and culture signature buttons move next to their luxury buildings.
- Generated files are committed. A `make gamedata` target regenerates them. A `make gamedata-check` target, run in CI and the pre-commit hook, fails when the committed output is out of date.
- No gameplay values change. During migration a parity test checks that every generated value equals the value hardcoded today, and a determinism baseline recorded on `main` before the change must match the fixture output afterwards.
- Agent tooling for pin-pointed content changes:
  - a semantic diff, `gamedata-gen diff <ref>`, that lists value-level changes (`Building sawmill: cost 120 → 130`) and ignores formatting;
  - Claude Code hooks in a committed `.claude/settings.json` that validate every agent write to a pack as it happens and block hand edits to generated Swift;
  - four project skills (`gamedata-tune`, `gamedata-add`, `gamedata-culture`, `gamedata-review`), each landing only with an eval suite that passes on Claude Haiku.
- Not in scope: house tier needs as data (follow-up change `tier-needs-data`), loading content at runtime, third-party mods, and full Kubernetes-style envelopes (`apiVersion`, `metadata`, `spec`). Signature behaviour, rivals, difficulty and goals stay in Swift for now and can follow later.

## Capabilities

### New Capabilities
- `game-data-catalog`: Game content (goods, buildings, recipes, cultures, techs, ages) is declared in schema-validated, feature-grouped YAML content packs and compiled into type-safe Swift by a deterministic generator, with a CI check against drift.

### Modified Capabilities
<!-- None. Catalog values, enum raw values and save formats stay the same; only where they are declared changes. -->

## Impact

- **Code**: `Packages/CityCore/Sources/CityCore/{Goods,Building,Production,Culture,Research,Age,AgeSignatures,CultureSignatures}.swift`, plus the tables in `World.swift`, `CityLife.swift` and `Systems/RivalSystem.swift`, lose their data. A new `Generated/` folder holds the replacements. Public API names stay the same. `CityUI/BuildTool.swift` loses its building-name `switch` and reads `BuildingKind.displayName`. `CityRender2D`'s `SpriteAnimation.operationalEntry` gains a `default:` branch. `CityPersistence` and the CLI need no changes.
- **New tool**: `Packages/GameDataGen`, a SwiftPM executable built with the existing toolchain (`xcrun swift run`). It adds no Homebrew dependency. It adds **Yams** (YAML parser, pinned to an exact version) as the repo's first third-party SwiftPM package. Only the generator uses it; CityCore and the apps do not, so runtime stays free of third-party code. Yams builds on Linux, and the generator must build in the Linux CI container (`swift:6.0-jammy`). Dependabot gets a `swift` ecosystem entry for it.
- **Build/CI**: new Makefile targets `gamedata` and `gamedata-check`. CI runs `GameDataGen`'s tests and `gamedata-check` on macOS and Linux, and builds once with a fixture pack. `Generated/` is excluded from SwiftFormat and from SwiftLint's length and complexity rules. A new pre-commit hook runs when files under `GameData/` or `Generated/` are staged.
- **Agent tooling**: new `.claude/settings.json` (hooks), `scripts/gamedata-hook.sh` and four skills under `.claude/skills/`. The hooks cost nothing for edits outside game data. The skill evals call a model and are run by hand (`make skills-eval`), not in CI.
- **Saves**: none. Enum raw values are kept byte for byte. The legacy `BuildingKind` decode aliases (`lumberjack_hut`, `town_center`) become data (`legacyIds`).
- **Determinism**: enum case order follows manifest order, then item order. The manifest is chosen so that `Good`, `Culture`, `Tech` and `Age` keep today's order, which the simulation depends on. `BuildingKind` order changes (signature buildings move next to their culture or age). Nothing in the simulation iterates it, and the cross-platform determinism fixture must stay byte-identical to confirm this.
