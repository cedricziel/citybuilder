## Why

The game has a sandbox and four standalone scenarios: First Harvest, The Guild Town, Steam and Smoke, and Island Rivalry. Nothing links them. A player who finishes one has no next step, no story and nothing to earn, and each scenario teaches only through its goal line. The owner asked for more to do and for "a couple of campaigns". Issue #237 sets the frame: a light campaign, a short card per chapter and no dialogue system, starting only once the economy rework has settled.

A campaign is also the cheapest way to make the systems we already have legible. Many players never touch the town market, research, ships or rivals. A chapter about one of them, with a goal the sim can check, teaches that system better than a hint can.

## What Changes

- **Three campaigns, 15 chapters.** Chapters are game data: map, start, unlocks, goals and card text.
  - **The Long Chronicle** has 6 chapters, from a stone village to the electric age. Each chapter teaches its age's mechanic. The first two take over the teaching of the first-hour guide (#185).
  - **The Merchant Sea** has 5 chapters on an archipelago: a first port, a far mine served by ship, orders from neighbours, a race against rivals, and mastery of the sea.
  - **Hard Ground** has 4 chapters of hardship, each played as one fixed culture: a thin forest, a long winter, a far vein, and a year of fire and fever.
- **Chapter start.** Each chapter fixes its layout, seed, start age, rival count and culture, or leaves the culture to the player. It sets the starting money and stock per difficulty, and which buildings and techs are open. It can reshape the map after generation with deterministic **terrain directives**, such as thinning the home forest or clearing the mountains near the town center.
- **Richer goals.** Today's goals are population, age, stock and outgrowing every rival. This change adds:
  - own N of a building, or complete a signature project;
  - research a tech;
  - a treasury of at least X, or a positive net per collection;
  - earnings from market or rival-port sales;
  - goods landed at a home port by ship;
  - keep another goal true for a whole season;
  - fulfil N orders, once orders exist.

  Any goal can be a **bonus goal**, which never blocks the win and earns a laurel.
- **Lose conditions.** Bankruptcy still ends any game. A chapter can also be lost by:
  - a **deadline**: its goals are still unmet at the start of a given year;
  - a **rival race**: a rival meets a named goal first;
  - a **collapse**: the population falls below a floor after first reaching it.
- **Progression.** Finishing a chapter unlocks the next one in its campaign. Merchant Sea and Hard Ground open when Chronicle chapter 3 is won. Progress lives in a small profile record outside the world saves and syncs through iCloud key-value storage. Rewards are cosmetic or new sandbox options: town banners, decor pieces, and each chapter's map as a sandbox map preset. Nothing the sandbox offers today gets locked.
- **Chapter select, intro and ending cards.** Each card is a short text with an illustration made from our own art. All of it needs a Claude Design canvas before any UI is built.
- **Bot-checked balance.** Every chapter has a PlayerBot configuration in the weekly sweep. Guided play must win on Easy and Normal. On Hard, a guided bot must still win at least sometimes, and a naive bot must mostly lose.
- **The old scenarios stay** in the New Game dialog. Their goals reappear inside Chronicle chapters 2, 3 and 5.

Out of scope:
- a dialogue or character system, voiced narration and cutscenes;
- carrying a city from one chapter to the next;
- scripted camera tours;
- per-culture copies of every chapter. Hard Ground fixes one culture per chapter instead.

## Capabilities

### New Capabilities
- `campaigns`: campaign and chapter definitions, chapter setup, terrain directives, progression and rewards, and the bot sweep per chapter.

### Modified Capabilities
- `difficulty-and-goals`:
  - adds the new goal kinds, bonus goals and lose conditions;
  - adds "Chapter setup";
  - the "Goals" requirement gains bonus goals and stops winning a lost game.
- `world-terrain`: terrain directives run after the starter grove and the starter mine site. A game without directives is generated exactly as today.
- `platform-shells`: the Campaigns entry, the chapter select screen, the intro and ending cards, and the goal, deadline and lose readouts in the HUD.

## Impact

- **Sequencing:**
  - Implementation starts after visible-distribution M2 (market porters and the marketplace, #238) and the wool → cloth chain (#239) have merged, as #237 asks.
  - Goals are tuned against per-good storage with producer backpressure, direct hops (#232) and porters. Tuning earlier means retuning after every economy change.
  - Chapters that need a roadmap feature ship in a later milestone than the ones that don't. Those features are orders, events with counterplay, winter needs and transport per age. Design D12 lists what each chapter needs.
- **CityCore:**
  - `Goal` gains cases, and `GoalState` gains `isBonus` and a holding timer.
  - `World` gains lose conditions, `scenarioLost` and a `scenarioLost` event.
  - A `ChapterSetup` builds a world from pack data, and terrain directives run in world generation.
  - All of it is deterministic and framework-free.
- **Saves:** the save version goes up for the new goal and lose state, with a migration that fills the defaults. Campaign progress is a separate profile record in CityPersistence.
- **Game data:** new `Campaign` and `Chapter` item kinds in a `campaigns.yaml` pack, plus a schema update.
- **CityUI:** the Campaigns entry, chapter select, the cards and the HUD readouts. All of it goes through a canvas first.
- **Tests:**
  - A sweep test per chapter, behind `RIVAL_SWEEP=1`.
  - The `PlayerBot` gains a sea kit, an order kit and a race mode.
  - Spec scenarios map to tests as usual.
- **Build tools:** none new.
