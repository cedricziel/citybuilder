# Game direction: answer pile

Raw answers from the direction quiz (2026-10-08), recorded before sorting into OpenSpec changes.

## Round 1: what the game is

- **Core fun:** optimising supply chains *and* watching a pretty, lively city grow.
- **Moving between ages:** a gradual drift, not a hard switch.
- **Platforms:** iPhone, iPad and Mac equally, each with its own layout.
- **Difficulty:** chosen at new game, next to the age.

## Round 2: progression and depth

- **What drives the drift:** a mix. Population tiers create demand, research unlocks supply, and calendar years bring events.
- **Older buildings in a later age:** houses restyle in place; production buildings are replaced by newer tech.
- **Chain depth:** 6+ steps at the longest (Anno 1800 depth).
- **Liveliness:** all of it. Walkers and carts, day/night and seasons, ambient sound, citizen voices.

## Round 3: scope and world

- **Span:** Antiquity → Modern (5 ages: Antiquity, Medieval, Renaissance, Industrial, Modern).
- **Culture:** picked at start, each with its own buildings and goods.
- **World:** solo for now, designed so AI rivals can be added later.
- **Game length:** both an endless sandbox and goal-based scenarios.

## Round 4: cultures, art, first slice

- **Cultures in the first version:** all four (Mediterranean, Northern European, East Asian, Middle Eastern).
- **Art:** one consistent style throughout, with buildings appropriate to each age. *There is no consistent style yet:* terrain and roads are procedural pixel art, and buildings are AI drawings in a different register.
- **Next slice:** deeper chains first (population tiers and longer chains in the current setting) before adding ages.
- **Signature mechanics:** both, one per age and one per culture.

## Sorted: proposed change sequence

Each item is one OpenSpec change, in dependency order. Bigger items may split when proposed.

1. **`unify-art-style`**: write the style bible for one pixel register (tile and building proportions, palette rules, outline, light direction) and redraw the current buildings procedurally in it. Every later change adds art, so the rules come first.
2. **`add-population-tiers`**: residents climb tiers (e.g. peasants → citizens → merchants) when needs are met, and each tier demands new goods. This drives demand for everything after.
3. **`deepen-production-chains`**: grow the current setting to 6+ step chains with multiple inputs (grain → flour → bread; flax → linen → clothes; clay → bricks; ore → tools). Warehouses get range and specialisation.
4. **`add-research`**: a knowledge resource (scholars, library) that unlocks buildings one at a time. This is the supply side of the gradual drift.
5. **`add-calendar-and-events`**: years pass, seasons shift (visuals and farming), and history events fire. This adds the time side of the drift and the stage for signature mechanics.
6. **`add-cultures`**: culture is chosen at new game. The data model holds per-culture goods, buildings and art sets, and Northern European (today's content) becomes the first culture.
7. **`add-historical-ages`**: Antiquity → Modern as overlapping eras. Houses restyle in place, production is replaced by newer tech, and the start age is chosen at new game. One signature mechanic per age.
8. **`add-culture-content`**: Mediterranean, East Asian and Middle Eastern goods and buildings, plus one signature mechanic per culture.
9. **`add-difficulty-and-goals`**: difficulty picked at new game (bankruptcy, unrest, disasters scale with it), plus goal-based scenarios beside the endless sandbox.
10. **`add-city-life`**: citizens on the streets, day/night, reactive ambient sound, and an inspector showing who lives in a house and what they want.
11. **`add-rival-towns`**: AI-run cities competing for islands and trade. Rivals stay out of scope until here, but each earlier change keeps the data model ready for them.

### Status (2026-10-08)

| # | Change | State |
|---|---|---|
| 1 | unify-art-style | archived |
| 2 | add-population-tiers | archived |
| 3 | deepen-production-chains | archived |
| 4 | add-research | archived |
| 5 | add-calendar-and-events | archived (seasons use drawn autumn/winter terrain; a tint can't lighten to snow) |
| 6 | add-cultures | archived |
| 7 | add-historical-ages | archived (age signatures split into `add-age-signatures`) |
| 8 | add-culture-content | archived (culture signatures split into `add-culture-signatures`) |
| 9 | add-difficulty-and-goals | archived |
| 10 | add-city-life | archived (ambient sound deferred until audio assets exist) |
| 11 | add-rival-towns + add-rival-trade | archived (rival ports cost money only; rival growth needs a balance pass) |
| — | add-touch-first-placement | archived (iPad and landscape playtests deferred) |
| — | add-age-signatures | archived |
| — | add-culture-signatures | archived |
| — | add-route-authoring-ui | archived (routes, manifests, route list and ship assignment were unreachable before; editing an existing route is not built) |

**In parallel, any time:** finish `add-touch-first-placement` (open, 0/28), the Mac runtime pass (deferred from the foundation), and archive `replace-procedural-sprites-with-ai-pipeline` (complete but not archived).

### Open questions for later

- Tier names and how many tiers per age.
- Whether research is a resource you spend or a rate that accumulates.
- How culture interacts with age: does every culture get all five ages, or do some ages differ by culture?
