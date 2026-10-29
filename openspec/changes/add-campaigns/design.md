## Context

Scenarios today are a Swift enum (`Scenario` in `Goals.swift`). Each one has an age, a difficulty, an optional required layout and a list of goals. Goals are checked every 10 ticks, and once all are met the world emits `scenarioWon`. The only way to lose is bankruptcy. The New Game dialog lists the scenarios next to the sandbox.

Facts that shaped the chapters:

- **Map shapes are fixed.** The single-island map is the same for every seed; the seed only drives history events. The archipelago always has the same five islands: home is island 1, temperate, 2,805 tiles; the others are 2,453 to 6,269 tiles. The seed changes only where forest and mountains fall. Across archipelago seeds 0–39, the home island holds 29–58 mountain tiles and 373–439 forest tiles. Its nearest mountain lies 2–11 tiles from the town center. A seed alone therefore cannot make a "thin forest" or a "far mine". That is why terrain directives exist (D6).
- **Ownership on the archipelago.** Islands without a rival stay the player's, each with its own seeded town center. With 1 rival, the player owns four islands. The ship chapters use that.
- **Pacing.** After `slow-the-mid-game`, a guided, consumer-first PlayerBot with the market reaches the Renaissance in a median of 5.8 years on Easy, 6.5 on Normal and 7.3 on Hard. Chapter deadlines are set from these and from the baseline in D10.
- **Sequencing.** Per-good storage with producer backpressure, direct hops (#232), market porters (#238 M2), handcarts (#238 M3) and the wool → cloth chain (#239) are all in flight. Each changes how fast a town grows. #237 asks for campaign work to start after #238 M2 and #239 have landed.

## Goals / Non-Goals

**Goals:**
- Two to three campaigns of 4–6 chapters, each chapter teaching one system and ending in a checkable win.
- Every goal and lose condition is computed from world state in CityCore, so the PlayerBot sweeps can prove guided play wins and Hard stays hard.
- Chapters are data: retuning after an economy change edits a pack, not Swift.
- The first two Chronicle chapters do the first-hour guide's teaching (#185).

**Non-Goals:**
- Dialogue, characters, cutscenes or a camera tour.
- Carrying a town from one chapter into the next.
- Hand-authored maps.
- Locking any option that sandbox games offer today.

## Decisions

### D1. Chapters are pack data, not Swift cases

A new `campaigns.yaml` pack holds `Campaign` and `Chapter` items, validated by the pack schema and generated into catalogs by `GameDataGen`, like every other pack. The old `Scenario` enum stays for the four standalone scenarios, with goals of the same type.

*Alternatives:*
- Extend the `Scenario` enum. That puts 15 chapters of tuning numbers in Swift, so each retune would be a code change.
- Turn the old scenarios into chapters. This would rewrite working tests for no player-facing gain. Chapters reuse their goals instead (D11).

### D2. One fixed seed per chapter, swept with nine neighbours

Each chapter fixes its seed, so every player plays the same map and the card text can talk about it. The sweep plays the chapter seed and seeds +1 to +9, with the same directives (`campaigns` / Every chapter passes its sweep). A chapter that only works on its own seed is overfitted, and history events differ per seed.

*Alternative:* sweep only the fixed seed. One deterministic run proves little: a single lucky event decides it.

### D3. Starting money and stock: one Normal value, scaled by difficulty

A chapter states its Normal money and stock. Easy and Hard scale them:

| | Money | Stock |
|---|---|---|
| Easy | ×1.5, rounded to $50 | ×1.5, rounded up |
| Hard | ×0.7, rounded to $50 | ×0.5, rounded up |

This matches today's spread ($1,500 / $1,000 / $700). A chapter can override a value for one difficulty when its sweep needs it. The difficulty keeps setting upkeep, grace, research cost and events.

*Alternative:* three hand-set triples per chapter. That is 45 numbers to keep consistent, and they drift.

### D4. A holding goal holds for one season

A holding goal needs its condition at every goal check for 600 ticks. A season is long enough that a town cannot win on a lucky spike, as Guild Town's "30 merchants" can today. It is short enough to read as one beat. This also brings back the idea of a sustained-merchants gate that `slow-the-mid-game` dropped. It belongs as a chapter goal, not a global era gate, until merchants hold steadily. Per-good storage with backpressure and the cloth chain (#239) are expected to bring that.

*Alternative:* a year. The baseline in this design shows merchants swinging between 0 and 60 within two years, so a year-long hold would make chapters unwinnable until merchants steady.

### D5. Losing ends the chapter, not the game

A deadline, a rival race or a collapse emits `scenarioLost`, stops goal checks and shows the lost card. The player can retry, or keep building in a finished game. Bankruptcy is the one loss that also stops commands, as today. It emits `scenarioLost` with the reason bankruptcy, next to `gameOver`, and keeps today's game-over tools. Deadlines are stored as years after the start year and shown as "years left".

*Alternatives:*
- Treat every loss like bankruptcy. That punishes the player twice.
- Have no deadlines at all. Then Hard is only a longer game, and the sweeps can't measure "Hard stays hard".

### D6. Terrain directives, not authored maps

Four directives change terrain after generation: thin forest, push the mine out, no mountains, and raise a mine site. The single-island map can't host a far mine, because its only mountains are a core about 12 tiles across near the centre, so Hard Ground 3 uses the archipelago home island with seafaring closed. They are deterministic in the seed and the tile. They run before rivals are seated and starter roads are laid, and they never change the island list.

*Alternatives:*
- Authored maps. These need a map editor, a new save path and art review per map.
- A new generator per chapter. That multiplies the code the fair-start sweep has to cover.

### D7. Progression: a short spine, then two branches

The Long Chronicle is the spine. Winning its chapter 3 opens The Merchant Sea and Hard Ground. By then the player knows the market, chains and research, which both branches take for granted. Inside a campaign, chapters open in order.

Rewards are banners, decor pieces and map presets. They only add options; nothing in today's sandbox is locked.

*Alternative:* open every chapter from the start. New players would land in "The Far Vein" without knowing what a mine is.

### D8. Progress is a profile record synced by key-value storage

Campaign progress is small: chapter ID, best difficulty, best laurels and rewards. It lives in a CityPersistence `CampaignProgress` record and syncs through iCloud key-value storage. The merge is a pure function, so two devices converge.

*Alternatives:*
- Store progress inside saves. Deleting a save would lose a win.
- A CloudKit record type. That is heavier, and it waits on the CloudKit production rollout (#68).

### D9. The chapters

Rules for every chapter:

- **Bot notation:**
  - *guided*: `PlayerBot.guideSteps` plus the market;
  - *careful* and *naive*: the `MidGameOrder`;
  - *kits*: the extra behaviour the chapter's bot needs (D10).
- The *naive* bot used for "Hard stays hard" plays with no first steps and the naive order. It trades at the market only where the chapter says so.
- **Deadlines** are given as an absolute year: the first tick of that year loses the chapter. Antiquity years are shown BC, with the astronomical year that `startYear` uses in brackets.
- **Money and stock** are the Normal values (D3).
- **Open** lists what the chapter adds to its age's normal research rules. **Closed** lists what it takes away.

#### The Long Chronicle (culture: the player's choice)

A town's history in six chapters, one map per age. It teaches one system per chapter.

| # | Title | Map | Age, rivals | Start (Normal) | Open / closed | Goals | Bonus | Lose | Teaches | Reward |
|---|---|---|---|---|---|---|---|---|---|---|
| 1 | **First Fires** | single island, seed 101 | Antiquity, 0 | $1,000; 6 wood, 5 planks, 2 food | Closed: everything but house, road, farm, lumberjack, forester, sawmill, warehouse | own 3 houses; 24 residents; net income ≥ $60 a season; earn $60 from trade | treasury ≥ $1,200; own 2 foresters | bankruptcy; deadline 497 BC (astronomical −496: three years after the 500 BC start) | food → residents → tax; planks for houses; tax against upkeep; the market as a valve (#185) | banner "Hearth" |
| 2 | **Bread and Stone** | single island, seed 102 | Antiquity, 0 | $1,000; 8 wood, 6 planks, 4 food | Open: grain farm, quern house, bakery, library, monument. Closed: Feudal Order | 40 residents; 20 bread in store; complete the monument | research Scholarship; hold 20 citizens for a season | bankruptcy; deadline 495 BC (astronomical −494) | a three-step chain with direct hops; a store filling and its bakery stopping (backpressure); a signature project | decor "Founder's stone" |
| 3 | **The Guild Charter** | single island, seed 103 | Medieval, 0; Feudal Order done | $1,200; 10 wood, 8 planks, 4 food | Closed: Seafaring | research Metallurgy; own a guild hall; 20 merchants; 20 tools in store | 30 merchants and 30 tools, the old Guild Town line; hold 20 merchants for a season | bankruptcy; deadline 1210 | research choices; the four-step tools chain; the marketplace and its porters; the guild hall's speed bonus; cloth as a merchant need (#239) | banner "Guild key"; opens The Merchant Sea and Hard Ground |
| 4 | **Across the Water** | archipelago, seed 104 | Medieval, 1 | $1,500; 10 wood, 10 planks, 6 food | none | research Seafaring; own a port and a shipyard; earn $400 from trade; 40 citizens | land 30 food at home by ship; fulfil 1 order (once orders exist) | bankruptcy; deadline 1207 | ports, ships, routes, rival ports and their offers | map preset "Across the Water" |
| 5 | **Steam and Smoke** | single island, seed 105 | Renaissance, 0; Feudal Order and Printing Press done | $1,200; 12 wood, 10 planks, 6 food | none | reach the Industrial age; 2 gallery commissions run to their end; own a steam engine | hold 40 merchants for a season; own 3 upgraded workshops (once upgrades exist) | bankruptcy; deadline 1462 | era gates; gallery commissions; fuel and the steam engine's smoke; carts change with the age (#236) | decor "Clock tower" |
| 6 | **The Electric Age** | single island, seed 106 | Industrial, 0; every earlier era tech done | $1,500; 12 wood, 12 planks, 6 food, 6 iron | none | reach the Modern age; own a power plant; 120 residents | hold 60 merchants for a season; treasury ≥ $3,000 | bankruptcy; collapse below 80 after reaching it; deadline 1795 | fuel logistics at scale; power against smoke; a large town's flows | banner "Lightning" |

**Card text:**

1. **First Fires**
   - *Intro:* "Smoke rises from one hearth on an empty shore. Twelve families followed you here with seed grain, axes and little else. Give them roofs and full bowls before the third winter, and they will call this place home."
   - *Ending:* "The hearths have multiplied. Tax coins ring in the strongbox, and traders on the coast now know the way to your market. A village has taken root."
2. **Bread and Stone**
   - *Intro:* "The village eats, but it eats porridge. The elders speak of loaves, and of a stone that will outlast everyone here. Mill the grain, bake the bread and raise a monument the sea can see."
   - *Ending:* "The monument stands on the hill, raised on bread and sweat. Every table has a loaf, and the scholars say a new age is turning."
3. **The Guild Charter**
   - *Intro:* "Merchants will not settle where there are no tools to buy and no guild to vouch for them. The charter is yours if the town can earn it: smiths, a guild hall, and full stalls in the market."
   - *Ending:* "The guild masters have sealed the charter. Carts of tools leave the smithies, and merchants' houses now line the square."
4. **Across the Water**
   - *Intro:* "There are other shores, and someone already lives on one of them. Build a port and a hull, and find out what your neighbours will pay for what you have too much of."
   - *Ending:* "Your sails are known in a harbour that is not your own. What the island lacks, the sea can now bring."
5. **Steam and Smoke**
   - *Intro:* "Printers, painters and bankers fill the town, but the future smells of coal. Feed the galleries, win over the merchants, and light the first engine before the century turns."
   - *Ending:* "The engine coughs, then roars. Smoke drifts over the rooftops, and every workshop on the street runs faster."
6. **The Electric Age**
   - *Intro:* "Wires are coming. A town this size needs power that does not choke its houses, and fuel enough to keep it running. Build the plant, keep the furnaces fed, and bring the light."
   - *Ending:* "At dusk the windows light up all at once. From a single hearth to a town that glows, the chronicle is complete."

**Chronicle 1 takes over the first-hour guide.** The guide's five steps become the chapter's goals. In a chapter game the "First steps" card stays hidden, because the goals panel says the same thing. The sandbox keeps the card.

#### The Merchant Sea (archipelago; culture: the player's choice; Seafaring done from chapter 1)

Five chapters about what an island cannot make alone.

| # | Title | Map | Age, rivals | Start (Normal) | Open / closed | Goals | Bonus | Lose | Teaches | Reward |
|---|---|---|---|---|---|---|---|---|---|---|
| 1 | **Two Shores** | seed 201; thin forest on home, keep 15% | Medieval, 1 | $1,500; 10 wood, 10 planks, 6 food | none | own a port on home and on the first island; land 60 planks at home by ship; 40 citizens | own 2 ships; treasury ≥ $1,500 | bankruptcy; deadline 1206 | routes between your own islands; producing where the land is good | map preset "Two Shores" |
| 2 | **The Far Vein** | seed 202; no mountains on home; raise a mine site on the first island | Medieval, 1; Mining done | $1,500; 10 wood, 10 planks, 6 food | none | research Metallurgy; 30 tools in store; 20 merchants | land 30 iron at home by ship (smelting at the mine halves the cargo); hold 20 merchants for a season | bankruptcy; deadline 1210 | long supply lines; where to put the processing step; ship capacity | map preset "The Far Vein" |
| 3 | **Orders from the Mainland** | seed 203 | Medieval, 2 | $1,200; 10 wood, 10 planks, 6 food | none | fulfil 6 orders; earn $1,500 from trade | fulfil every accepted order on time; own 3 ships | bankruptcy; deadline 1208 | orders, favour, planning production for a date | banner "Seal and sail" |
| 4 | **The Printing Race** | seed 204; rivals may enter the Renaissance from 1207 (Easy 1209, Hard 1206) | Medieval, 2 | $1,000; 8 wood, 8 planks, 5 food | none | reach the Renaissance | outgrow every rival when you win; earn $800 at rival ports | bankruptcy; rival race "first to the Renaissance"; deadline 1212 | rivals as competitors; trading with the rival who is ahead, or not | decor "Press stone" |
| 5 | **Mistress of the Sea** | seed 205 | Medieval, 3 | $1,200; 10 wood, 10 planks, 6 food | none | outgrow every rival, held for a season; 100 residents; earn $3,000 from trade | 3 ships on routes; treasury ≥ $3,000 | bankruptcy; collapse below 60 after reaching it; deadline 1214 | everything at once against three rivals | banner "Sea star" |

**Card text:**

1. **Two Shores**
   - *Intro:* "The home island's woods were cut long ago. Across the strait the forest still stands, and your people already keep a town there. Join the two shores by sea."
   - *Ending:* "Timber crosses the strait with every tide. Two shores, one town."
2. **The Far Vein**
   - *Intro:* "There is no ore under home soil, only under a rocky island a day's sail away. Dig there, and decide what crosses the water: raw ore, or finished bars."
   - *Ending:* "The smithies ring again. The vein is far, but the route is sure."
3. **Orders from the Mainland**
   - *Intro:* "The crown wants timber for its fleet, and the neighbours want bread for their winter. Every order filled is coin and goodwill; every one broken is remembered."
   - *Ending:* "Your seal is trusted on every quay. When the mainland needs something, it asks you first."
4. **The Printing Race**
   - *Intro:* "Two towns across the water want the printing press as badly as you do. The first town to print will set the tone for an age. Trade with them, or race them, but be first."
   - *Ending:* "The first pages come off your press while the neighbours are still carving type. The new age begins here."
5. **Mistress of the Sea**
   - *Intro:* "Three rival towns, one sea. Outgrow them all, keep your routes full and your strongbox heavier still."
   - *Ending:* "Every harbour flies your colours beside its own. The sea is a road now, and it leads to you."

#### Hard Ground (each chapter fixes one culture)

Four short, harsh chapters. Each one leans on its culture's signature building.

| # | Title | Culture | Map | Age, rivals | Start (Normal) | Open / closed | Goals | Bonus | Lose | Teaches | Reward |
|---|---|---|---|---|---|---|---|---|---|---|---|
| 1 | **The Thin Forest** | Mediterranean (forum taxes) | archipelago seed 301; thin forest on home, keep 15% | Medieval, 0 | $800; 6 wood, 6 planks, 3 food | Closed: Seafaring | 30 citizens; own 4 foresters; hold 30 residents for a season | own a forum; treasury ≥ $1,000 | bankruptcy; collapse below 25 after reaching it; deadline 1206 | forestry as an economy; wood backpressure (what to stop when wood is short); the forum's tax ring | map preset "The Thin Forest" |
| 2 | **The Long Winter** | Northern European (mead hall halves upkeep) | single island, seed 302 | Medieval, 0 | $900; 8 wood, 6 planks, 6 food | none | 50 citizens; hold 40 citizens for a season | 60 food in store at the first day of winter; own a mead hall | bankruptcy; collapse below 30 after reaching it; deadline 1206 | storing ahead of winter; firewood; the mead hall | map preset "The Long Winter" |
| 3 | **The Long Road** | Middle Eastern (caravanserai exports) | archipelago seed 303; push the mine out to 16 tiles | Medieval, 0; Mining done; Seafaring closed | $1,000; 8 wood, 8 planks, 4 food | none | research Metallurgy; 25 tools in store; 25 merchants | own a caravanserai; hold 25 merchants for a season | bankruptcy; deadline 1210 | long hauls by road; warehouses near the mine; handcarts (#238 M3); export income while the road is built | map preset "The Long Road" |
| 4 | **Fire and Fever** | East Asian (temple gardens add knowledge) | archipelago seed 304 | Medieval, 2 | $1,000; 8 wood, 8 planks, 5 food | none | 60 residents; own a fire watch and a physician | no building lost to fire; hold 60 residents for a season | bankruptcy; collapse below 40 after reaching it; deadline 1206 | events with warning and counterplay; spacing a town; knowledge from temple gardens to research cures | map preset "Fire and Fever" |

**Card text:**

1. **The Thin Forest**
   - *Intro:* "Goats and old fires have stripped these hills. Every tree is precious. Plant before you cut, build what pays, and let the forum's coin carry the rest."
   - *Ending:* "Young groves cover the slopes again. The town learned to count its trees, and it will not forget."
2. **The Long Winter**
   - *Intro:* "The old ones say this winter will be long. Fill the stores while the fields still give, cut firewood while the ground is soft, and keep the mead hall warm."
   - *Ending:* "Spring found every chimney still smoking. The winter took its toll, but it did not take the town."
3. **The Long Road**
   - *Intro:* "The iron lies far beyond the last house, at the end of a road not yet built. Make the long haul worth it, and let the caravans earn while the road is laid."
   - *Ending:* "Handcarts rumble down the long road day and night. The vein was far, but the town reached it."
4. **Fire and Fever**
   - *Intro:* "A dry year, and talk of fever in the harbour towns. Watchers and healers cost coin, and ruins cost more. Read the warnings, and build before they come true."
   - *Ending:* "The year of fire and fever has passed. The town is scarred, but standing, and wiser."

### D10. Bot configuration per chapter

The weekly sweep plays each chapter with a guided bot and a naive bot (`campaigns` / Every chapter passes its sweep). New kits extend the `PlayerBot` test support. They live in tests only, like the mid-game kit:

- **signature:** builds the age's signature once its inputs flow, and starts commissions.
- **sea:** builds a port and a shipyard on two named islands of its own, launches a ship and authors one route carrying a good. A second route comes when the chapter needs one.
- **trade:** sells surplus at rival ports with the sea kit's ship.
- **orders:** accepts any order it could fill with 1.5× its current production, and otherwise ignores it.
- **winter:** before autumn, raises its food and wood targets to the winter line.
- **events:** builds the counterplay building for each warning it sees.

| Chapter | Guided bot | Naive bot | Kits |
|---|---|---|---|
| Chronicle 1 | guide steps, market | no steps, no market | — |
| Chronicle 2 | guided, careful (quern house) | naive | signature |
| Chronicle 3 | guided, careful | naive | — |
| Chronicle 4 | guided, careful | naive | sea, trade |
| Chronicle 5 | guided, careful | naive | signature |
| Chronicle 6 | guided, careful | naive | signature |
| Merchant Sea 1 | guided, careful | naive | sea (planks: first island → home) |
| Merchant Sea 2 | guided, careful | naive | sea (ore or iron: first island → home) |
| Merchant Sea 3 | guided, careful | naive, ignores orders | sea, trade, orders |
| Merchant Sea 4 | guided, careful | naive | sea, trade |
| Merchant Sea 5 | guided, careful | naive | sea ×2 routes, trade |
| Hard Ground 1 | guided, careful | naive | — |
| Hard Ground 2 | guided, careful | naive | winter |
| Hard Ground 3 | guided, careful | naive | — |
| Hard Ground 4 | guided, careful | naive | events |

**Gates:**
- **Easy:** the guided bot wins 10 of 10 runs.
- **Normal:** the guided bot wins at least 9 of 10. One loss is allowed so an unlucky event year doesn't fail the build.
- **Hard:** the guided bot wins 4 to 9 of 10. Fewer than 4 means a careful player is shut out. Ten of ten means Hard is no harder than Normal.
- **Naive bot on Hard:** wins at most 3 of 10.

The deadlines and targets in D9 are first values. The milestone that ships a chapter tunes them against these gates and writes the measured table into this section.

**Baseline for the first values:** see "Baseline measurements" below.

### D11. The standalone scenarios stay

First Harvest, The Guild Town, Steam and Smoke and Island Rivalry stay in the New Game dialog. Their goals reappear in Chronicle 2, 3 and 5, and in Merchant Sea 5. They are a quick game; a chapter is the guided version.

### D12. What each chapter needs that doesn't exist yet

Every chapter needs the campaign core (M1): pack kinds, the chapter setup, the new goals, holding and bonus goals, lose conditions, directives, progress and the UI. Beyond that:

| Chapter | Needs, in flight | Needs, new (roadmap issue) |
|---|---|---|
| Chronicle 1 | — | — |
| Chronicle 2 | per-good storage, direct hops (#232) | — |
| Chronicle 3 | marketplace and porters (#238 M2), cloth (#239) | charters #260 (optional) |
| Chronicle 4 | — | orders #255 (bonus only) |
| Chronicle 5 | carts per age (#236) | upgrades #262 (bonus only) |
| Chronicle 6 | carts per age (#236) | — |
| Merchant Sea 1 | — | fertility #261 (optional) |
| Merchant Sea 2 | — | — |
| Merchant Sea 3 | — | **orders #255 (required)** |
| Merchant Sea 4 | — | rival age years (M1); rival attitudes #263 (optional) |
| Merchant Sea 5 | — | rival attitudes #263 (optional) |
| Hard Ground 1 | per-good storage | — |
| Hard Ground 2 | per-good storage | **winter needs #259 (required)** |
| Hard Ground 3 | handcarts (#238 M3) | — |
| Hard Ground 4 | — | **events #257 (required)** |

The other new mechanics are part of the core milestones: terrain directives, the trade-earnings and landed-by-ship counters, chapter build lists, the rival race and the rivals' earliest year per age. Chronicle 5 and 6 also depend on merchants holding, which #239 and per-good storage are expected to bring.

### D13. Chapter select and cards follow the approved canvas

The canvas is https://claude.ai/artifact/7RVf4CiyHoJpgyBgEa1Q35. It shows today's New Game dialog and win sheet as the "before", and three options each for chapter select and for the cards.

- **Chapter select: option C, a split view.** Campaigns and their chapters are listed on the left. The chosen chapter is on the right, with a render of its map, its intro line, its goals and bonus goals, its start and its limits, the difficulty picker, the culture picker when the chapter leaves the culture open, and Start. On iPhone the split view collapses to the list (option A), and choosing a chapter pushes its detail.
- **Cards: option B, a sheet with a map header.** The intro and ending cards are the existing sheet with a render of the chapter's map at the top. They match the goals panel and the win sheet they replace, they work on iPhone, and they hold a goal list and 320 characters of text. The lost card is the same sheet, small, with Retry, Keep building and Back to chapters. The parchment surface stays for in-world banners.

*Alternatives:* a road of chapters drawn on the map (select B) needs a hand-placed path per campaign and hides each locked chapter's key behind a tap. Parchment cards (cards A) would spend the in-world surface on long menu text. Glass cards over the live map (cards C) make 320 characters hard to read over busy art.

## Baseline measurements

The first values in D9 come from a scratch sweep on main at 3936db41. It is not committed. The PlayerBot played guided, with the market, for 10 years: the careful mid-game kit for Medieval starts, and no mid-game kit for Antiquity starts. Seeds 0–3, single island and archipelago; the Easy archipelago arms are left out of the table. Each cell shows residents / merchants, the age, and stored bread / tools.

| Arm | Year 2 | Year 4 | Year 6 | Year 8 | Year 10 |
|---|---|---|---|---|---|
| Antiquity, single, Easy | 43–58 | 35–44 | 42–73 | 60–101 | 71–131 |
| Antiquity, single, Normal | 29 | 37–64 | 36–73 | 38–103 | 77–123 |
| Antiquity, single, Hard | 17–23 | 32–61 | 35–82 | 54–94 | 71–79 |
| Medieval, single, Normal | 29 / 0 | 45 / 0, bread 87 | 69–88 / 8–10 | 95–126 / 8–10, Renaissance | 102–143 / 0–16 |
| Medieval, single, Hard | 16–19 / 0 | 43–49 / 0 | 75–94 / 6–16 | 99–129 / 14–33, Renaissance | 99–162 / 0–23 |
| Medieval, archipelago, Normal | 16–23 / 0 | 31–65 / 0 | 57–122 / 6–22 | 76–115 / 8–14, Renaissance | 95–128 / 0–58 |
| Medieval, archipelago, Hard | 17–26 / 0 | 30–52 / 0 | 36–73 / 0 | 69–139 / 0–14; seed 2 bankrupt at the end of year 8 | 84–175 / 8–45 (3 seeds), Renaissance |
| Rivals' largest town, archipelago, Normal / Hard | 27–46 / 45–63 | 51–75 / 63–73 | 53–77 / 62–68 | 49–82 / 55–76 | 54–82 / 63–71 |

What this means for the chapters:

- **Single-island seeds don't vary the map.** On Normal, seeds 0–2 played identically to year 6. The sweep's nine neighbour seeds (D2) vary only the history events there. That is enough to catch an event-sensitive chapter, but not a terrain-sensitive one.
- **Antiquity towns mostly stay below 30 citizens** without bread. Chronicle 1's 24 residents by its deadline, the start of 497 BC, is met on Normal and Easy by year 2, and on Hard between year 2 and 4. That matches the gates.
- **Merchants don't hold today.** The bot's merchants swing between 0 and 60 within two years, and tools rarely stay above 10. The old Guild Town line, 30 merchants and 30 tools, is met in almost no run. Chronicle 3 asks for 20 / 20, with 30 / 30 as a bonus, and the holding goals stay bonus goals until #239 and per-good storage steady the merchants.
- **Chronicle 5 and 6 are out of reach today.** Steam power needs 40 merchants and electricity 60, and the bot reaches 40 only on the archipelago late in year 10. They are designed for the post-#239 economy and must be remeasured first (task 0.1). If they still miss, the era gates are a chapter-level override, not a global retune.
- **Rivals' timing depends on the seed, not the player.** On Normal, rivals level off at 53–56 residents on three of four seeds, short of the 60 the Renaissance needs. On the fourth seed one reaches 75 by year 4. On Hard they pass 63 by year 4 on every seed. A residents-only race would be decided by the map, not by play. Merchant Sea 4 therefore sets an earliest year per age for rivals (`campaigns` / Chapter setup), and the year moves with difficulty.
- **The Renaissance arrives in years 7–8 on Normal and 8–10 on Hard.** This is in line with the 6–8 year target. Medieval chapters that end at the Renaissance get deadlines of 1210–1212.

## Risks / Trade-offs

- **[Risk]** The economy rework moves every number again after the chapters are tuned. → Chapters are data (D1), and the sweep runs weekly. A chapter that falls out of its gates fails the sweep and gets a data retune, not a redesign. Implementation waits for #238 M2 and #239 (#237).
- **[Risk]** Fixed seeds make a chapter feel scripted on a replay. → History events and rival choices vary with the difficulty. Map presets let a player who wants variety take the map into the sandbox.
- **[Risk]** Bot kits grow into a second AI that is harder to maintain than the rival AI. → Kits stay in test support, reuse `RivalTownPlan` and `RivalAI` where they can, and each one is a few dozen lines with its own test.
- **[Risk]** Required features (orders #255, winter #259, events #257, handcarts #238 M3) slip, and four chapters wait. → Those chapters ship in the last milestone. Until then the pack marks them as coming later, and unlocking skips them (`campaigns` / Chapter progression). Winning Merchant Sea 2 opens Merchant Sea 4, and winning Hard Ground 1 opens nothing more until a later chapter ships. So The Long Chronicle is complete from M4, The Merchant Sea is playable with a gap, and Hard Ground has one chapter until its features land.
- **[Risk]** Deadlines feel punishing to players who like to build slowly. → On Easy, deadlines are a third longer than on Normal. The lost card offers "keep building", and the sandbox has no deadlines.
- **[Trade-off]** Laurels and banners are a small reward. → This is on purpose: the campaign is a guided path through the game, and the sandbox is the game. Rewards that changed the sandbox's balance would split the player base's experience.

## Determinism

Everything new in CityCore is a pure function of world state or of pack data:

- **Goal and lose checks** read the world at the goal interval and never draw from the RNG.
- **Holding timers and trade counters** are integer fields of `World`. They are saved and compared in equality, so replays stay byte-identical.
- **Terrain directives** use a hash of the seed and the tile coordinate, never the world's random generator. They run at a fixed point in generation.
- **Chapter setup** is `World.generate` with explicit parameters. The `DeterminismFixture` gains one chapter start, with directives, so the macOS-vs-Linux gate covers it.

**Framework-free invariant:** chapter types, goals and directives live in CityCore with Foundation only. Profile sync with iCloud key-value storage lives in CityPersistence, and the cards and chapter select live in CityUI.

## Open Questions

- Should Easy lengthen deadlines by a third (Risks) or drop them? The sweep on Easy will show whether the guided bot ever comes near one.
- Does the Hard Ground culture order want a fifth chapter, so each of the four cultures appears in another campaign too?

## Gameplay depth roadmap

Filed alongside this change, ranked by fun per effort and by fit with the owner's direction: a visible economy, backpressure and a slower mid-game. The statistics screen (#256) helps every chapter. Each issue names the chapters that use it.

1. #255 Orders from the crown and neighbours
2. #256 Statistics screen
3. #257 Events with warning and counterplay
4. #258 Service needs in reach
5. #259 Winter needs
6. #260 Charters, one choice per age
7. #261 Soil fertility per crop
8. #262 Workshop upgrades
9. #263 Rival attitudes

Considered and not filed:
- **Maintenance and decay.** It is upkeep in another form, a chore with no visible payoff. Backpressure already gives the economy friction.
- **A full tech-tree rework.** Charters (#260) give the real choice at a fraction of the cost.
- **More population tiers.** Service needs (#258) give the existing tiers distinct wants first.
