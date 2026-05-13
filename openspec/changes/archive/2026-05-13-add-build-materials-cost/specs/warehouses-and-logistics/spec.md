## ADDED Requirements

### Requirement: Cross-warehouse partial withdrawal API

`Stockpile` SHALL expose a withdrawal API that callers (notably `World.applyPlace`) can use to take a specific amount of a good. When a single warehouse lacks the full requested amount, the caller iterates additional warehouses to cover the shortfall. The withdrawal call itself MUST be atomic per-warehouse: it MUST NOT partially withdraw and report success — it withdraws exactly `amount` or returns the amount actually withdrawn so the caller can advance.

#### Scenario: Withdrawal returns actual amount taken

- **WHEN** a warehouse holds 3 wood and `withdraw(.wood, amount: 5)` is called
- **THEN** the warehouse's wood drops to 0 and the withdrawal returns `3` (the amount actually taken)

#### Scenario: Withdrawal from sufficient warehouse takes exactly the requested amount

- **WHEN** a warehouse holds 5 wood and `withdraw(.wood, amount: 3)` is called
- **THEN** the warehouse's wood drops to 2 and the withdrawal returns `3`

### Requirement: Island warehouse query

`World` SHALL expose a deterministic query for all goods-buffer buildings (warehouse + port + shipyard) anchored on a given island, sorted by ascending road-distance from a reference anchor. The query underlies `applyPlace`'s deduction loop and any future "find me wood" lookups.

#### Scenario: Query returns goods buffers on the named island only

- **WHEN** Island #1 has two warehouses and Island #2 has one warehouse, and the query asks for Island #1
- **THEN** the query returns exactly Island #1's two warehouses

#### Scenario: Query order is shortest road-distance first

- **WHEN** Island #1's two warehouses sit at road-distances 3 and 7 from the reference anchor
- **THEN** the warehouse at distance 3 appears first in the result
