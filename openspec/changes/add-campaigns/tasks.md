## 0. Gate

- [ ] 0.1 Confirm visible-distribution M2 (#238) and the wool → cloth chain (#239) have merged. Rerun the baseline in design.md on the new main and update the chapter targets before starting M1.
- [ ] 0.2 Claude Design canvas for the chapter select screen and the intro, ending and lost cards: today's New Game dialog and win sheet as the "before", 2–3 options, a recommendation, and the owner's go-ahead.

## 1. M1 — Goals and lose conditions

- [ ] 1.1 Tests-first: translate every scenario of `difficulty-and-goals` in this change into failing tests in CityCoreTests, and confirm they fail.
- [ ] 1.2 Implement to green: the new goal kinds, the trade-earnings and landed-by-ship counters, holding goals and bonus goals.
- [ ] 1.3 Implement to green: lose conditions (deadline, rival race, collapse) and `scenarioLost`, plus bankruptcy as a loss.
- [ ] 1.4 Bump the save version, write the migration that fills the defaults, and add a fixture from the previous version.
- [ ] 1.5 Refactor under a green bar.
- [ ] 1.6 Verify `make test-scenarios` is clean for `difficulty-and-goals`.

## 2. M2 — Chapters as data, setup and terrain directives

- [ ] 2.1 Tests-first: translate the `campaigns` scenarios for data, setup, build lists and progression, and the `world-terrain` scenarios, into failing tests, and confirm they fail.
- [ ] 2.2 Implement to green: the `Campaign` and `Chapter` pack kinds, the schema, `GameDataGen` output, and load validation.
- [ ] 2.3 Implement to green: terrain directives in world generation.
- [ ] 2.4 Implement to green: `ChapterSetup`, covering rival count, money and stock scaling (design D3), pre-researched techs and build lists.
- [ ] 2.5 Implement to green: the `CampaignProgress` record with merge and key-value sync in CityPersistence.
- [ ] 2.6 Add one chapter start with directives to `DeterminismFixture`.
- [ ] 2.7 Refactor under a green bar.
- [ ] 2.8 Verify `make test-scenarios` is clean for `campaigns` and `world-terrain`.

## 3. M3 — UI

- [ ] 3.1 Tests-first: translate the `platform-shells` scenarios into failing CityUITests, and confirm they fail.
- [ ] 3.2 Implement to green: the Campaigns entry and chapter select, following the approved canvas.
- [ ] 3.3 Implement to green: the intro, ending and lost cards, and the goals panel readouts.
- [ ] 3.4 Hide the "First steps" card in chapter games (design D9).
- [ ] 3.5 Update `design/web` with the new screens and cards, and republish the design system after merge.
- [ ] 3.6 Refactor under a green bar.
- [ ] 3.7 Verify `make test-scenarios` is clean for `platform-shells`.

## 4. M4 — Twelve chapters that need nothing new

- [ ] 4.1 PlayerBot kits: signature, sea and trade (design D10), each with its own test.
- [ ] 4.2 Chapter sweep harness behind `RIVAL_SWEEP=1`: the guided and naive bots, chapter seed +0…+9, Easy, Normal and Hard; prints a `CHAPTER_SWEEP` line per run.
- [ ] 4.3 Author The Long Chronicle 1–6 in `campaigns.yaml`. Tune each against the gates and record the measured table in design D10.
- [ ] 4.4 Author The Merchant Sea 1, 2 and 4, and tune them.
- [ ] 4.5 Author The Merchant Sea 5 without rival pressure, and tune it.
- [ ] 4.6 Author Hard Ground 1 and 3, and tune them. Hard Ground 3 waits for handcarts (#238 M3).
- [ ] 4.7 Write the card text into the pack, and check that each text is 320 characters or fewer.
- [ ] 4.8 Add the "Guided play wins every chapter" and "Hard stays hard" sweep tests for these chapters.
- [ ] 4.9 Refactor under a green bar.

## 5. M5 — Chapters that need roadmap features

- [ ] 5.1 The Merchant Sea 3, once orders exist: orders kit, authoring and tuning.
- [ ] 5.2 Hard Ground 2, once winter needs exist: winter kit, authoring and tuning.
- [ ] 5.3 Hard Ground 4, once events with counterplay exist: events kit, authoring and tuning.
- [ ] 5.4 Add these chapters to the sweep tests.

## 6. Wrap-up

- [ ] 6.1 Run `make lint && make format`, `/simplify`, and `openspec validate add-campaigns --strict`.
- [ ] 6.2 Play each campaign's first chapter on a Mac and an iPad — DEFERRED (requires hardware playtest by the owner)
