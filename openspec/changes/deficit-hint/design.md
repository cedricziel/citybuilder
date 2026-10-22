## Context

`bankruptcyWarning` fires on the tick the player's treasury first falls below zero. Taxes and upkeep book on the same tick every 50 ticks, so that tick is almost always a collection, and the gap between that collection's upkeep and tax is the cause. The session already shows short announcements in its parchment banner (`SessionBanner`), which history events, new ages and signature buildings use.

## Goals / Non-Goals

**Goals:**
- Tell a player in the red why, and what to do, once.

**Non-Goals:**
- A new panel, a per-building breakdown, or a hint that repeats.

## Decisions

### D1. The session banner, paused until dismissed

The hint reuses the session banner, so its style is that of every other announcement, with one Resume button added. On Normal the bankruptcy grace is 50 ticks, about 5 seconds at normal speed, so a timed banner would give way to "Bankrupt" before a new player could read it, let alone act. The hint therefore pauses the simulation while it shows. The grace does not run while paused, so the player gets time to sell, demolish or rebuild.

The pause is the hint's own, not the pause menu: the menu is a sheet that would cover the hint. `step()` does nothing while the hint shows. Resume, the pause control or, on the Mac, Esc dismisses it and resumes. On Apple TV the Resume button takes focus so the remote can dismiss it.

On the tick it shows, the hint takes the place of any other banner that tick raises: year turns land on collection ticks, so a history event, a new age or an out-of-fuel banner can arrive with it.

### D2. Once per session, and on load

The session remembers that it showed the hint; nothing is saved. Loading a save emits no `bankruptcyWarning`, because the deficit counter is saved too, so a session that starts with the treasury below zero, and the game not over, shows the hint at once. Either way it shows at most once per session.

### D3. Tax and upkeep from CityCore

`World.playerTaxAndUpkeep` returns one collection's tax and difficulty-scaled upkeep for the player, through the same per-owner tax and upkeep code the economy system runs, with the same signature sources. The banner reads it when it shows, after that tick's collection, so the figures are the ones that caused the deficit.

## Risks / Trade-offs

- **The figures always show the cause.** Purchases and placements check the balance before they spend, so only a collection can take the treasury below zero: whenever the hint shows, that collection's upkeep exceeded its tax.
- **A paused hint interrupts play.** That is the point for a player about to lose the town, and it happens once per session.

## Migration Plan

None.
