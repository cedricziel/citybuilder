## 1. Buys reach the island's stores

- [x] 1.1 Tests-first: translate `town-market` "Full town center", "A full town center buys into a warehouse", "The town center fills first" and "Stores on another island stay out of a buy", and `platform-shells` "Buy enabled while a warehouse has room", into failing tests; confirm red
- [x] 1.2 Implement to green: `marketBuy` deposits into the island's operational player goods buffers, town center first, then ascending entity ID (design D1, D2)
- [x] 1.3 Implement to green: `MarketReach.freeSpace` sums the same buffers' free space (design D3)
- [x] 1.4 Confirm the `DeterminismFixture` output is unchanged
- [x] 1.5 Refactor under a green bar
- [x] 1.6 Run `SCENARIO_COVERAGE_STRICT=1 make test-scenarios` and confirm no uncovered scenario from this change

## 2. Road-connected stores first (#113)

- [ ] 2.1 Tests-first: "Stores the town center's roads reach fill first" and "Warehouses fill before ports"; confirm red
- [ ] 2.2 Implement to green: purchase order town center, connected warehouses, connected ports, then the rest by kind, each by entity ID (design D2)
