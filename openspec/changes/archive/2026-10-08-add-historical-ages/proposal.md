## Why

The game's twist is that the player chooses the historical age to start in, then drifts forward. The pieces for the drift are in place — population tiers create demand, research unlocks supply, the calendar brings events — but there are no ages to drift through. This change adds the five ages from Antiquity to Modern, the choice of starting age, and the mechanics of moving from one age to the next.

## What Changes

- **Ages:** Antiquity, Medieval, Renaissance, Industrial and Modern. Each has a start year (500 BC, 1200, 1450, 1780, 1910).
- **Starting age:** the New Game dialog offers the age next to the culture. Starting later grants every tech of the earlier ages, sets the calendar to that age's start year and restyles the town.
- **Advancing:** each later age has an era tech in the research tree (Feudal Order → Medieval, Printing Press → Renaissance, Steam Power → Industrial, Electricity → Modern). An era tech needs the previous one and can only be chosen once the city is big enough: 20 citizens for Feudal Order, then 20, 40 and 60 merchants. Researching it moves the city into the next age, jumps the calendar forward to that age's start year if it is behind, and announces the new age with a banner.
- **Techs belong to ages:** Scholarship is an Antiquity tech; Milling, Mining, Metallurgy and Seafaring are Medieval. Grain farms and bakeries no longer need Milling, so Antiquity can bake bread from quern-ground flour.
- **Houses restyle in place:** each age has its own look for all three house tiers, combined with the culture's style (stone and columns in Antiquity, today's look in Medieval, tall stuccoed fronts in the Renaissance, brick and chimneys in the Industrial age, rendered concrete in the Modern age).
- **Production is replaced:** a building can be made obsolete by a later tech. Existing ones keep working, but they can no longer be placed and the palette hides them. The first pair: the Antiquity **quern house** (a hand mill: 2 grain → 1 flour every 80 ticks) is replaced by the windmill when Milling is researched.
- **Saves:** a v6 → v7 migration puts existing saves in the Medieval age.

Signature mechanics per age and further per-age buildings follow in later changes.

## Capabilities

### New Capabilities

- `historical-ages`: ages, the starting age, era techs, advancing, calendar jumps and obsolescence.

### Modified Capabilities

- `research`: era techs, per-age techs, residents gates and a narrower Milling.
- `buildings-and-construction`: the quern house and obsolete buildings.
- `persistence-save-load`: the v6 → v7 migration.
- `platform-shells`: the age picker, the age banner and hidden obsolete palette entries.
- `rendering-2_5d`: age-styled houses.
- `sprite-style-catalog`: age house variants and the quern house.

## Impact

- **CityCore:** `Age`, `World.age`, era techs in `Tech`, `newGame(layout:seed:culture:age:)`, `BuildingKind.quernHouse`, obsolescence rules, `WorldEvent.ageAdvanced`, BC years in `GameDate`.
- **CityPersistence:** save version 7.
- **CityUI:** age picker, age banner, palette filtering.
- **CityRender2D:** house sprite lookup by age and culture.
- **Art:** house tiers per age and culture (48 new sprites), the quern house.
