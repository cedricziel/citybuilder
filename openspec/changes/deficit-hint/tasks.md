## 1. Deficit hint

- [x] 1.1 Tests-first: "Deficit hint names the cause" and "Deficit hint shows once", plus a CityCore test that `playerTaxAndUpkeep` matches what the next collection credits and deducts; confirm red
- [x] 1.2 Implement to green: `World.playerTaxAndUpkeep`, sharing the economy system's tax and upkeep code (design D3)
- [x] 1.3 Implement to green: the hint in `SessionBanner`, once per session, for 150 ticks (design D1, D2)
- [x] 1.4 Run `SCENARIO_COVERAGE_STRICT=1 make test-scenarios` and confirm no uncovered scenario from this change
