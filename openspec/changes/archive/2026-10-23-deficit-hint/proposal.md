## Why

The #72 measurement found that a town whose upkeep outruns its tax goes broke without ever recovering: 7 of 20 Normal archipelago games, when the scripted player never uses the market. A new player who doesn't know about the market hits exactly that. Today the only signal is the treasury figure turning red and, at the end, the "Bankrupt" banner.

## What Changes

- The first time in a session that the treasury is below zero, including on loading a save in the red, the game shows a banner naming the cause, "In the red: upkeep $X vs tax $Y", and three fixes: sell surplus at the town center's market, demolish idle buildings, or build houses before more huts.
- The hint pauses the simulation until the player dismisses it, so the bankruptcy grace can't run out while they read.
- CityCore exposes the player's tax and upkeep for one collection, computed by the same code the economy system uses.

Out of scope: a new screen or panel, and per-building upkeep breakdowns.

## Capabilities

### New Capabilities
- (none)

### Modified Capabilities
- `platform-shells`: adds "Deficit hint".

## Impact

- **CityCore**: `World+Economy.swift`, a read-only `playerTaxAndUpkeep`.
- **CityUI**: `SessionBanner.swift` shows the hint through the existing session banner with a Resume button; the session's step and pause control and the Mac's Esc handling know about it.
- **Determinism**: none; the simulation is unchanged.
