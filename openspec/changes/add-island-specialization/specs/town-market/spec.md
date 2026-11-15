## ADDED Requirements

### Requirement: Luxury import
While the player's culture's garden yields 0% on the player's home island of an archipelago game, the town market SHALL sell the culture's luxury good to the player with a seasonal buy limit of 12 at 200% of its base price, rounded down. Its sell terms SHALL stay those of its pack. The import SHALL count against the player's seasonal ledger like any purchase, SHALL be listed in the snapshot's market, and SHALL NOT be offered in a single-island game or in a save whose home island grows every garden. Rival market trades SHALL keep their pack terms. The numbers SHALL be content.

#### Scenario: Beer is imported when hops cannot grow
- **WHEN** a Northern European player in a new archipelago game with $500 and room in the town center asks to buy 4 beer
- **THEN** the town center gains 4 beer and the balance drops by $128

#### Scenario: Import seasonal limit
- **WHEN** that player has bought 10 beer this season and asks to buy 5 more
- **THEN** 2 beer are bought

#### Scenario: No import on a single island
- **WHEN** a Northern European player in a single-island game asks to buy 1 beer
- **THEN** nothing changes and no `marketTraded` event is emitted

#### Scenario: Import keeps buying above selling
- **WHEN** the import price of every luxury is compared with the market's sell price, the caravan price and every rival price for that good
- **THEN** the import price is higher than all of them
