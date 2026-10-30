Each milestone is one PR. Every key a milestone adds ships with its English and reviewed German value (design D9); German stays hidden from players until M7.

## 1. M1 — Catalogs, lookup, pseudo-locale and the check

- [ ] 1.1 Tests-first: translate "Tests resolve text in a pinned language", "The pseudo-locale lengthens and marks a string", "The pseudo-locale keeps placeholders", "Numbers use the locale's grouping" and every "fails the check" / "Complete catalogs pass the check" scenario into failing tests (CityUITests and L10nCheckTests); confirm red
- [ ] 1.2 Implement to green: `defaultLocalization: "en"`, `Resources/Localizable.xcstrings` in CityUI, and the `GameText` lookup with an explicit `Language` chosen from `Bundle.main.preferredLocalizations`, with tests for English-system/German-app and German-system/English-app (design D1, D3)
- [ ] 1.3 Implement to green: the pseudo-locale transform and the `-CBPseudoLocale` launch argument (D10)
- [ ] 1.4 Implement to green: the `Tools/L10nCheck` package (rules library, `l10n-check` executable, tests), `glossary.json` from the spec table, `make l10n-check`, the lint-job step and the pre-commit hook (D8)
- [ ] 1.5 Run `L10nCheckTests` in `make test` and in CI (beside the IsoKit tests, selected by `scripts/select_ci_jobs.py` when `Tools/L10nCheck` changes) (D8)
- [ ] 1.6 Move the pause menu to the catalog as the first real keys (en + de), so "German locale shows German text" and "An unsupported language falls back to English" have a subject; make those tests green
- [ ] 1.7 Refactor under a green bar
- [ ] 1.8 Verify `make test-scenarios` and `make l10n-check` clean for this milestone's scenarios

## 2. M2 — CityUI static strings

- [ ] 2.1 Tests-first: a test per screen that resolves its labels in English and asserts today's text, plus one German assertion per screen; confirm red
- [ ] 2.2 Implement to green: title screen, new-game dialog, chapter select, pause menu, settings, statistics, research, goals and standings panels, tool strip, build rail and Mac menu literals through the catalog
- [ ] 2.3 Implement to green: accessibility labels through the catalog
- [ ] 2.4 Add the SwiftLint custom rule banning string literals in `Text(`, `Button(`, `Label(`, `.navigationTitle(` and `accessibilityLabel(` in CityUI (D3)
- [ ] 2.5 Refactor under a green bar
- [ ] 2.6 Verify `make test-scenarios` and `make l10n-check` clean

## 3. M3 — CityUI sentence builders

- [ ] 3.1 Tests-first: translate "Counts pick the plural form" and "English keeps today's text" into failing tests; add German assertions for each builder below; confirm red
- [ ] 3.2 Implement to green: `SessionBanner` and its seasonal-event, fuel, monument, commission, rival and bankrupt banners, with plural keys (`count.building`, `count.resident`) (D6)
- [ ] 3.3 Implement to green: `PlacementRejectionText` and the demolition texts
- [ ] 3.4 Implement to green: inspector lines (production, needs, ruins, signatures, market, fuel)
- [ ] 3.5 Implement to green: orders board, route list, manifest editor, town and rival market, first-steps guide, event chip, status pills
- [ ] 3.6 Refactor under a green bar (one German template per sentence, no article before a noun placeholder, D7)
- [ ] 3.7 Verify `make test-scenarios` and `make l10n-check` clean

## 4. M4 — CityCore keyed messages

- [ ] 4.1 Record the determinism fixture's post-tick JSON on `main` before the change
- [ ] 4.2 Tests-first: translate "A history event carries its key and amount", "A date before year 1 reads per locale" and "Keyed messages leave the simulation unchanged" into failing tests; confirm red
- [ ] 4.3 Implement to green: `GameMessage` and `MessageArg` in CityCore; `HistoryEvent`, `Scenario`, `Season` and `Difficulty` expose keys and messages; remove `GameDate.displayText` (D4)
- [ ] 4.4 Implement to green: CityUI formats messages and dates through the catalog; add the keys with en + de
- [ ] 4.5 Refactor under a green bar; confirm 100% diff coverage of the CityCore lines and `scripts/check-no-apple-ui-imports.sh` clean
- [ ] 4.6 Verify `make test-scenarios` and `make l10n-check` clean

## 5. M5 — Pack text keys

- [ ] 5.1 Tests-first: translate "A pack name gets a derived key", "German values survive regeneration", "Changing English text marks German for review", "A removed pack item drops its keys", "Pack placeholders are named" and "A noun placeholder is filled with the localized noun" into failing tests (GameDataGenTests and CityUITests); confirm red
- [ ] 5.2 Implement to green: the catalog emitter in GameDataGen with the merge rules and Xcode's JSON layout, writing to a `--catalog` path; `gamedata-check` covers `GameData.xcstrings`, and `scripts/check-gamedata-fixture-build.sh` passes a scratch catalog path (D5)
- [ ] 5.3 Make catalog edits trigger the drift check: add `GameData.xcstrings` to the `gamedata-check` pre-commit `files:` pattern and to GameDataGen's inputs in `scripts/select_ci_jobs.py` (D5)
- [ ] 5.4 Implement to green: generated Swift exposes key strings and drops the English members; CityUI resolves names, units, blurbs, banners and order texts through `GameData.xcstrings`, filling `{names}` after the lookup (D6)
- [ ] 5.5 Author the German values for every pack key, following the glossary
- [ ] 5.6 Refactor under a green bar
- [ ] 5.7 Verify `make gamedata-check`, `make test-scenarios` and `make l10n-check` clean

## 6. M6 — Rival names

- [ ] 6.1 Tests-first: translate "A generated rival name shows in German" and "An unknown rival name shows as stored" into failing tests; confirm red
- [ ] 6.2 Implement to green: `rivalTown.<slug>` keys for every generated name, looked up at display time (D12)
- [ ] 6.3 Verify `make test-scenarios` and `make l10n-check` clean

## 7. M7 — Tight labels, overflow fixes and switching German on

- [ ] 7.1 Tests-first: translate "Tight labels fit in German" and "Tight labels fit in the pseudo-locale" into failing tests with the tight-label list and width budgets (D11); confirm which labels are over budget
- [ ] 7.2 Design the layout fixes on a Claude Design canvas when they change the HUD visibly; get the go-ahead
- [ ] 7.3 Implement to green: shorter German where the glossary allows, then layout fixes; keep `design/web` in step
- [ ] 7.4 Implement to green: "German locale shows German text" end to end; add `de` to the supported languages, `knownRegions` and `CFBundleLocalizations` in `project.yml`
- [ ] 7.5 Translate "German text uses the glossary words" and "German text addresses the player with du" into tests over the shipped catalogs; make them green
- [ ] 7.6 Playtest a German and a pseudo-locale session in the simulator for strings that bypass the catalog — DEFERRED (requires the orchestrator's simulator slot)
- [ ] 7.7 Refactor under a green bar
- [ ] 7.8 Verify `make test-scenarios` and `make l10n-check` clean for every scenario of the change
