## Context

`bankruptcyWarning` fires on the tick the player's treasury first falls below zero. Taxes and upkeep book on the same tick every 50 ticks, so that tick is almost always a collection, and the gap between that collection's upkeep and tax is the cause. The session already shows short announcements in its parchment banner (`SessionBanner`), which history events, new ages and signature buildings use.

## Goals / Non-Goals

**Goals:**
- Tell a player in the red why, and what to do, once.

**Non-Goals:**
- A new panel, a per-building breakdown, or a hint that repeats.

## Decisions

### D1. The session banner, for 150 ticks

The hint reuses the session banner, so the layout and style are those of every other announcement. It shows for 150 ticks instead of 60 because its description is a sentence of three fixes. A later banner replaces it, as with any other banner, and the game-over banner takes its place once the game is over.

### D2. Once per session

The session remembers that it showed the hint; nothing is saved. A player who loads a save in the red sees the hint again once, which is when it is useful.

### D3. Tax and upkeep from CityCore

`World.playerTaxAndUpkeep` returns one collection's tax and difficulty-scaled upkeep for the player, through the same per-owner tax and upkeep code the economy system runs, with the same signature sources. The banner reads it on the warning tick, after that tick's collection, so the figures are the ones that caused the deficit.

## Risks / Trade-offs

- **A deficit can have another cause.** A purchase or a construction cost can take the treasury below zero while tax still covers upkeep. The figures then show it, and the fixes still apply.

## Migration Plan

None.
