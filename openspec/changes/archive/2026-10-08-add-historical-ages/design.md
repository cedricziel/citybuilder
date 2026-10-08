## Context

See proposal.md (Why). Research (`Tech`, `ResearchState`), the calendar (`CalendarState`, derived `GameDate`) and cultures (`Culture`, culture sprite lookup with fallback) exist. Saves are at version 6. House sprites resolve as `building-house[-tierN][-<culture>]`.

## Decisions

### D1 — `Age` is an ordered enum on `World`

`Age` (`antiquity`, `medieval`, `renaissance`, `industrial`, `modern`) is `Comparable`, `Codable` with string raw values, and has a `displayName` and `startYear` (−499, 1200, 1450, 1780, 1910). `World.age` defaults to Medieval, so fixtures keep today's content. `WorldSnapshot.age` carries it.

### D2 — Years before 1 AD

`GameDate.displayText` shows years ≤ 0 as BC using astronomical numbering: year 0 is 1 BC, so −499 reads "500 BC".

### D3 — Techs belong to ages; era techs move between them

`Tech.age`: Scholarship → Antiquity; Milling, Mining, Metallurgy, Seafaring → Medieval. Antiquity is a short opening age: houses, timber, farms, the quern-house bread chain and the library, with Feudal Order as its only research. Grain farm and bakery no longer need Milling, so the Antiquity bread chain works; Milling unlocks the windmill alone.

Four era techs, each `era: Age?` naming the age it opens, with a residents gate:

| Era tech | Opens | Needs | Cost | Gate |
|---|---|---|---|---|
| Feudal Order | Medieval | — | 150 | 20 residents at citizens or above |
| Printing Press | Renaissance | Feudal Order | 250 | 20 merchants |
| Steam Power | Industrial | Printing Press | 400 | 40 merchants |
| Electricity | Modern | Steam Power | 600 | 60 merchants |

The first gate counts citizens because Antiquity has no tools, so merchants can't exist yet. A regular tech can be chosen when its age is at or before the world's age. An era tech can be chosen only when it opens the age right after the world's age and its gate is met. The gate is checked when choosing, not while researching, so a dip in population doesn't cancel progress.

### D4 — Advancing

When an era tech completes, `World.age` becomes its age, `WorldEvent.ageAdvanced(Age)` fires, and if the date's year is before the age's start year, `calendar.startYear` moves forward by the difference so the current year becomes the start year. The date stays derived from the tick count.

### D5 — Starting age

`World.newGame(layout:seed:culture:age:)` sets `age`, researches Scholarship, every regular tech whose age is before the start age and every era tech up to the start age (so a Medieval start is today's opening: Scholarship and Feudal Order), and sets `calendar.startYear` to the age's start year. Existing overloads default to Medieval.

### D6 — Obsolete buildings

`BuildingKind.obsoletedBy: Tech?`. When that tech is researched, `canPlace` rejects the kind with `.obsolete(Tech)` and the palette hides it; existing buildings keep working. The quern house (2×2, $60, 2 wood + 2 planks; 2 grain → 1 flour every 80 ticks) is available from the start and obsoleted by Milling.

### D7 — Age house sprites

House looks by age and culture are named `building-house[-tierN]-<age>[-<culture>]`, with the age omitted for Medieval and the culture omitted for Northern European, so today's names stay valid. Lookup tries age+culture, then age, then culture, then the shared name. The building kit composes `style(culture, age)`: the culture's style with the age's materials and shapes (Antiquity: ashlar and low roofs, columns on tier 3; Renaissance: taller stucco fronts, cornices; Industrial: brick, more chimneys; Modern: rendered concrete, flat roofs, wide windows).

### D8 — Age banner

The session's banner shows "The <Age> age begins" with a one-line description when `ageAdvanced` fires; history events and age changes share one banner slot, last one wins.

### D9 — Migration v6 → v7

Adds `age: "medieval"` and adds Feudal Order to the researched list (kept sorted), because a Medieval city has passed it. `SaveFile.currentVersion` becomes 7.

## Risks / Trade-offs

- **[Risk] 48 house sprites** → Mitigation: procedural style composition in one loop; the content gate checks every one.
- **[Risk] Gate sizes are too high or low** → Mitigation: one table, tuned at runtime check.
- **[Risk] Starting in Modern with only medieval production** → Accepted for now: later changes add per-age production; the starting age already changes look, techs, calendar and the quern/windmill chain.
