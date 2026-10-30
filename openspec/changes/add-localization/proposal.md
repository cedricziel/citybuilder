## Why

Every player-visible string is hardcoded English: about 80 SwiftUI `Text` literals, a few hundred sentences built in CityUI's view models and banners, hand-written English in CityCore (goals, history events, dates), and English names and banner texts in the pack YAML. The owner is a native German speaker and wants a German game (#351). German is the first language besides English; the work has to leave further languages cheap.

## What Changes

- A String Catalog becomes the only route to the screen. English is one locale among others, German is the second. The game follows the system or per-app language and has no in-game language switch.
- CityCore stops producing English sentences. Where it describes something to the player (history events, goals, dates, seasons, difficulty), it exposes a stable key plus typed arguments, and CityUI turns them into text. No simulation state, save field, RNG draw or tick order changes, so determinism and sweep results stay identical.
- Pack YAML stays the single source for content. GameDataGen gives every player-visible pack field (names, units, blurbs, banner titles and texts, order texts, campaign chapters) a derived key and writes the English values into a generated catalog. German entries for those keys are authored in the same catalog and survive regeneration. An English edit in YAML marks the German entry for review.
- A pseudo-locale renders every string about 40% longer with accents and brackets. Tests use it to measure tight labels; playtests use it to find truncation and strings that bypass the catalog.
- A CI check fails when a catalog key lacks a reviewed German translation, when a German string's placeholders differ from the English ones, or when code names a key the catalog does not have.
- A German glossary and tone guide (du-form, period-appropriate words) lives in the spec, and every German string follows it.
- Rival town names, which are stored in the save, are translated at display time, so the save format is unchanged.

## Capabilities

### New Capabilities

- `localization`: how player-visible text reaches the screen in the player's language: the catalogs, keyed messages from the core, pack-text keys, the pseudo-locale, the completeness check and the German glossary.

### Modified Capabilities

None. Existing scenarios that quote English text keep holding under the English locale, which the `localization` spec requires explicitly.

## Impact

- **CityCore**: `HistoryEvent`, `Scenario`, `Season`, `GameDate`, `Difficulty` and the generated catalogs gain keys and arguments in place of English `String` properties. The framework-free invariant holds: keys are plain strings, and CityCore never looks text up.
- **GameDataGen**: a new emitter writes `Packages/CityUI/Sources/CityUI/Resources/GameData.xcstrings`; `gamedata-check` covers it.
- **CityUI**: gains `defaultLocalization: "en"`, a `Resources` folder with `Localizable.xcstrings` and `GameData.xcstrings`, and a small lookup layer every view and view model goes through. Banner and inspector sentence builders move to catalog templates with plural variations.
- **Apps**: `project.yml` declares `de` in `knownRegions` and `CFBundleLocalizations`; the Mac menu's literals move to the catalog.
- **CI**: a new `make l10n-check` target, run in the lint job. The check is a small dependency-free Swift package under `Tools/`; no new tool dependency (`xcstringstool` ships with Xcode).
- **Layout**: German runs about 30% longer. Tight buttons (#305, #308) get fixes in the slice that ships German; any visible layout change goes through a Claude Design canvas.
- **Out of scope**: languages beyond English and German; an in-game language picker; localized audio; translating the CLI and PlayerBot reports, which stay English.
