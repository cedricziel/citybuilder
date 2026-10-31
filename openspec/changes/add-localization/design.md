## Context

- Player-visible text lives in three places today. CityUI holds most of it: SwiftUI literals and sentence builders in view models (`SessionBanner`, `PlacementRejectionText`, the inspector line builders, `OrdersBoardModel`). CityCore holds hand-written English (`HistoryEvent.title`/`description`, `Scenario.title`/`blurb`, `Season.displayName`, `GameDate.displayText`, `Difficulty.displayName`). Generated CityCore code holds the pack text (`displayName`, `blurb`, `stackUnit`, order `title`/`text`, `SeasonalBanner` templates with `{named}` placeholders, filled by `SessionBanner.fill`).
- CityUI already composes most sentences from CityCore enums and events (`WorldEvent`, `PlacementRejection`), so the core mostly hands over facts already. The English in CityCore is display text that rides along, not simulation state: no `World` field, save field or RNG draw reads it. The CLI, PlayerBot and the determinism fixture don't print any of it (checked).
- Rival town names are stored strings in `World` and the save (`WorldLayout` picks them at world generation).
- SwiftPM 6.4 builds `.xcstrings` into `<lang>.lproj` folders of the package bundle under `swift build` and `swift test`, but SwiftPM 6.3 (Xcode 26.6, the CI toolchain) only copies the file. So the lookup cannot rely on `Bundle`'s compiled tables (D3).
- `Text("literal")` in a package looks the key up in the main bundle, not the package's, so a literal in CityUI never reaches a CityUI catalog. Every lookup must name the bundle.

## Goals / Non-Goals

**Goals:**
- One lookup path for all player text, with the language chosen explicitly so tests are reproducible on a German Mac.
- German complete and reviewed before players see it; English unchanged for existing tests and specs.
- Small, independently reviewable PRs, each with the check strict from the start.

**Non-Goals:**
- An in-game language picker, right-to-left layout, or languages beyond English and German.
- Runtime grammatical inflection of nouns.
- Translating the CLI, PlayerBot reports, logs, `fatalError` messages and save-integrity errors (developer text).
- Changing the currency symbol or number semantics. German shows the same money, grouped the German way.

## Decisions

### D1. The catalogs live in CityUI, in two tables

`Packages/CityUI/Sources/CityUI/Resources/` holds `Localizable.xcstrings` (hand-written UI text and the core's keyed messages) and `GameData.xcstrings` (generated from the packs). `Package.swift` sets `defaultLocalization: "en"` and processes `Resources`. The three app targets declare `knownRegions: [en, de]` and `CFBundleLocalizations` so the system and the per-app language setting in iOS Settings offer German. The Mac menu's few literals use the same lookup through CityUI.

Alternatives: a catalog in the app targets (main bundle) lets `Text("literal")` work unchanged, but `swift test` can't see it, so no test could assert German; it also means three targets share one file through `project.yml`. One catalog per package spreads text across packages that have almost none (CityRender2D and CityPersistence show no player text). A single table mixes generated and hand-edited keys, which makes the generator's merge riskier.

### D2. Semantic dotted keys, not English-as-key

Keys name what the text is for: `pause.resume`, `banner.monumentComplete.title`, `history.bountifulHarvest.text`. English is the `en` value like any other language.

Alternatives: English-as-key, Xcode's default, extracts automatically. But extraction only syncs the catalog when building inside the Xcode IDE, not under `xcodebuild` in CI or `swift build`, so it wouldn't guard anything. It also orphans the German whenever an English sentence is reworded. Pack keys have to be semantic anyway (D5).

### D3. One lookup layer with an explicit language

CityUI gets a `GameText` lookup: `GameText.string(_ key: TextKey, _ args: ...)`, a `Language` value (`en`, `de`, `pseudo`), and SwiftUI helpers so views write `Text(.pause.resume)`-style keys through it. `TextKey` is a string-backed value; call sites use literals so the check (D8) can find them. Lookup reads the catalog's JSON itself: `Package.swift` copies `Localizable.xcstrings` into the bundle unchanged, and `StringTable` parses it once and picks plural forms by the language's CLDR rule ("one" for exactly 1 in English and German). This works the same under every toolchain and Xcode, and never relies on `Bundle.preferredLocalizations`. A language with more plural categories adds its rule to `StringTable`. `Language.current` comes from `Bundle.main.preferredLocalizations.first`, which honours the per-app language chosen in iOS Settings or macOS's Language & Region, mapped to the supported set and read once at launch; the mapping is a pure function of the preferred list and the supported set, so tests cover English-system/German-app and German-system/English-app without a device. Tests get `en` unless they ask for another.

A SwiftLint custom rule bans string literals in `Text(`, `Button(`, `Label(`, `.navigationTitle(` and `accessibilityLabel(` in CityUI, so new text can't bypass the catalog. Non-text literals use `Text(verbatim:)`.

Alternatives: `String(localized:bundle:)` at every call site works but follows the process's preferred languages, so a test run on the owner's German Mac would see German and fail English assertions. SwiftGen-style generated accessors would add a build tool (an onboarding cost the project rules call out).

### D4. CityCore exposes keys and typed arguments

CityCore gains a framework-free `GameMessage { key: String; args: [String: MessageArg] }`. `MessageArg` holds `int` and `money`, what history events need; further cases (`date`, `good`, `building`, `tier`, `season`, `text`) join when a message needs them. A message's catalog text names its arguments as `{food}`-style placeholders (D6), which CityUI fills after the lookup, so a translation can reorder them and `l10n-check` matches the names. English `String` properties become keys and messages:

- `HistoryEvent.title`/`description` become `titleKey` and `message`, whose arguments are the constants the simulation uses (`World.harvestFood`, `caravanPayment`, `scholarKnowledge`). The amounts stop being duplicated in prose.
- `Scenario.title`/`blurb`, `Season.displayName` and `Difficulty.displayName` become `titleKey`, `blurbKey` and `nameKey`.
- `GameDate.displayText` goes away; CityUI formats a date from season and year with the keys `date.ad` and `date.bc`; the year goes in as text, because `%lld` groups digits in German ("1.203").

Everything new is computed from existing enums. Nothing is stored, encoded, hashed or read by a system, so the `World` value, saves, RNG draws and tick order are untouched. CityCore still imports only Foundation and never looks text up; the framework-free check keeps passing.

Alternatives: keeping English in CityCore as a fallback next to keys leaves two sources of English and lets new code reach for the English one. Moving the enums' text wholesale into CityUI switch statements works, but scatters the amounts' link to their constants.

### D5. Pack text keys are derived; the generator merges the catalog

Every player-visible pack field gets the key `<kind>.<id>.<field>`, kind in lowerCamel: `good.wood.name`, `good.wood.unit`, `building.grainFarm.name`, `tier.merchants.name`, `culture.eastAsian.tierName.merchants`, `age.medieval.blurb`, `seasonalEvent.fire.banner.warning.title`, `order.crownWood.text`, `chapter.<id>.intro`. The generated Swift exposes these as static key strings (`nameKey`, `blurbKey`, `unitKey`, `SeasonalBanner(titleKey:textKey:)`) and drops the English `displayName`, `blurb`, `stackUnit`, `title` and `text`.

GameDataGen gains a catalog emitter. It reads the committed `GameData.xcstrings`, writes each key's `en` value from the YAML, keeps every other language's entry, sets a kept entry's state to `needs_review` when the YAML's English differs from the committed English, and drops keys whose item is gone. It writes the file in Xcode's own JSON layout (sorted keys, the same spacing), so an edit in Xcode's catalog editor round-trips without churn. `gamedata-check` compares this file like the Swift output. The catalog's output path is a generator argument (`--catalog`), so `scripts/check-gamedata-fixture-build.sh` writes it into its scratch copy and never touches the working tree. A `GameData.xcstrings` edit triggers `gamedata-check`: the pre-commit hook's `files:` pattern and `scripts/select_ci_jobs.py` both count the catalog path as a GameDataGen input, so a hand edit to an English value can't merge without being compared to the YAML.

Alternatives: German in the YAML (`name: { en: Wood, de: Holz }`) keeps everything in one file, but puts translations where the catalog tools, the check and future translators don't look, and every new language widens every YAML item. A one-time catalog import loses the single source for English.

### D6. Named placeholders in pack text, format specifiers in UI text

Pack text keeps `{building}`-style placeholders. CityUI looks the template up in the player's language, then fills names with already-localized values; this is today's `fill`, moved after the lookup. Hand-written UI text uses format specifiers (`%lld`, `%@`, positional `%1$@` where German reorders) so the catalog's plural variations work. A count inside pack text (`{residents} left the town`) is filled with a phrase from a plural UI key (`count.resident` gives "3 residents" or "3 Einwohner"). The pack sentence itself never varies by number.

Alternatives: converting pack placeholders to format specifiers would let pack text use plurals directly, but translators lose the names and the YAML stops being readable.

### D7. German phrases around nouns instead of inflecting them

German articles and adjectives agree with a noun's gender and case, and the noun arrives as an argument. German templates therefore put a noun placeholder where no article is needed: a headline ("Brand: {building}"), after a colon, or as a subject without an article ("{building} brennt"). The check rejects an article or `ein`-word directly before a noun placeholder. The glossary records genders for authors' reference only.

Alternatives: Foundation's automatic grammar agreement (`^[...](inflect: true)`) inflects some German, but its coverage of arbitrary game nouns and case is not something tests can pin. Per-noun gender variations would need a key per gender for every template, and the catalog has no gender axis.

### D8. The check is a small Swift package with tests

`Tools/L10nCheck` is a SwiftPM package with a library (the rules), an executable (`l10n-check`) and a swift-testing suite over small fixture catalogs. The scenario gate counts only `@Test` names under `Packages/` and `Tools/`, so the check's scenarios need real tests; a bare script with a `--self-test` mode would leave them unmapped. It parses both catalogs and enforces every rule in the spec: German present and `translated`, specifiers and `{names}` matching per plural form, no unknown keys looked up in `Packages/*/Sources` and `Apps`, no article before a noun placeholder, no avoided glossary word, no formal address. The glossary's avoided words live in `Tools/L10nCheck/glossary.json`, mirrored from the spec table. `make l10n-check` runs it with `xcrun swift run`, in the CI lint job and in pre-commit when an `.xcstrings`, a Swift source under CityUI or the glossary changes. Its own tests run too: `make test` gains `swift test --package-path Tools/L10nCheck`, and CI runs them next to the IsoKit tests, selected whenever `Tools/L10nCheck` changes. It has no dependencies.

Alternatives: a `swift` script like `check-scenario-coverage.swift` is lighter, but its self-test can't map scenarios. `xcstringstool` validates syntax but knows nothing about missing languages or our rules. A suite inside CityUI would need the whole package built in the lint job.

### D9. German ships with each slice and is switched on last

The check is strict from the first PR: every key a slice adds comes with English and German, so the owner reviews German in small pieces next to the code that uses it. Players don't see German until the last slice adds `de` to the supported languages and `knownRegions`, after the tight-label fixes. Until then a German device keeps getting English.

Alternatives: a single translation PR at the end means an allowlist of untranslated keys that grows for weeks, and one huge German review. Switching German on per slice would ship a half-German game to TestFlight.

### D10. The pseudo-locale is a runtime transform

`Language.pseudo` takes the English value and maps letters to accented look-alikes (`a`→`à`, `e`→`é`), pads to 140% with `~`, and wraps the text in `[` `]`. It leaves format specifiers and `{names}` alone. The app turns it on with the launch argument `-CBPseudoLocale YES`. Tests resolve in it directly. A string without brackets on screen bypassed the catalog; a cut bracket is an overflow.

Alternatives: Xcode's `NSDoubleLocalizedStrings` doubles the text but doesn't mark it, needs a scheme setting, and doesn't reach `swift test`. A real `en-XA` catalog column would need maintaining for every key.

### D11. Tight labels have width budgets measured in tests

A list in CityUI's tests names each tight label (the tool strip, the build rail, the pause menu, pills and chips), its font and its width in points. A test measures the German and the pseudo text with CoreText at that font and fails over budget. A pseudo overflow can be listed as known with an issue number; German has no such escape. It catches regressions like #305 and #308 without a simulator. Visible layout changes the fixes need go through a Claude Design canvas.

### D12. Rival names are looked up at display time

The UI looks a rival's stored name up under `rivalTown.<slug>` (`Bay of Knives` → `rivalTown.bayOfKnives`) and shows the stored name when the key is missing. The world and save keep the English name, so old saves, determinism and the CloudKit schema are untouched.

### Determinism

No change touches what the simulation reads or writes. Keys and messages are computed properties of existing enums, the generated catalogs change only their text members, and rival names are translated after the fact. The determinism fixture's post-tick JSON is compared before and after the CityCore slice, and the CityCore diff is held to full diff coverage.

## Risks / Trade-offs

- [The check can't see keys built at runtime, such as `"tool.\(kind)"`] → Dynamic keys are allowed only for generated pack keys, built through helpers the check knows (`nameKey` and friends). Everything else uses a literal `TextKey`. Pack keys are covered because the generator emits every one.
- [German makes labels longer than the HUD allows] → The pseudo-locale and the width budgets of D11 catch it in tests; the fixes ship before German is switched on (D9).
- [Hundreds of call sites change, so text could regress in English] → English values copy today's strings exactly. Existing tests asserting English keep running under the pinned `en` language and must stay green unchanged.
- [Hand edits to `GameData.xcstrings` in Xcode reformat the file] → The emitter writes Xcode's layout, and `gamedata-check` shows any churn.
- [Translators edit German in a generated file] → Only `en` is generated; the merge keeps other languages, and the self-tests cover the merge rules.
- [The glossary's avoided words hit legitimate German] → Avoided words are whole words, case-sensitive and few. A false hit is fixed by narrowing the glossary, not by an inline exemption.
- [A slice ships German nobody sees yet] → That's intended (D9). The owner reviews German in each slice's PR.

## Migration Plan

No save migration: nothing stored changes. Each slice is revertible on its own. German turns on with the last slice, and turning it off again is one line (the supported-language set).

## Open Questions

- Spelling of "Missernte": the issue writes the pre-1996 "Mißernte". The glossary uses modern spelling unless the owner prefers the older one for period flavour; it's a glossary edit either way.
- Currency: German shows the same symbol as English. A period currency word ("Taler") would be a gameplay-presentation change for another issue.
