## ADDED Requirements

### Requirement: Order events

The tick SHALL emit `orderOffered`, `orderAccepted`, `orderFulfilled`, `orderFailed` and `orderExpired`, each once, in the tick the order changes state, carrying the order's ID. `orderFulfilled` SHALL also carry the reward, and `orderOffered` the issuer. These events SHALL NOT be persisted and SHALL NOT influence the simulation.

#### Scenario: Order events are emitted once

- **WHEN** an order is offered, accepted, fulfilled in later ticks
- **THEN** each of those ticks emits the matching event once and later ticks emit none of them

#### Scenario: Failing and expiring emit their events

- **WHEN** one order fails and another lapses
- **THEN** the ticks emit `orderFailed` and `orderExpired` for them
