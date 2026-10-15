## ADDED Requirements

### Requirement: Player trades leave rivals alone

The player's market trades SHALL NOT change any rival's treasury, island stock, prices, offers or market counts. Rivals trade at their own town centers under `rival-towns` / Rival market trades, and those trades SHALL NOT count against the player's limits.

#### Scenario: Market trade leaves rivals alone
- **WHEN** the player sells 20 wood at the market in an archipelago game
- **THEN** every rival's treasury, island stock, offers and market counts are unchanged

## REMOVED Requirements

### Requirement: Rivals stay off the market
**Reason**: Rivals now trade at their own town center's market as a safety valve (`rival-towns` / Rival market trades, design D5 of `rival-ai-viability`). The part about the player's trades leaving rivals alone stays, as "Player trades leave rivals alone".
**Migration**: None. Existing saves have no rival market counts, so rivals start the season with fresh limits.
