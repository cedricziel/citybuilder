## 1. Readable market on Apple TV

- [x] 1.1 Tests-first: translate the `platform-shells` scenarios "Goods the island cannot use are collapsed", "Goods the island holds are shown" and "Inspector callout width per idiom" into failing CityUI tests; confirm red
- [x] 1.2 Implement to green: `TownMarketSection.rows` and `otherRows`, the "Other goods (N)" button in `TownMarketView`, and `InspectorCalloutLayout.width(for:)`
- [x] 1.3 Check the market on the tvOS simulator through the callout: rows readable without mid-word wraps, Other goods expands, and the remote reaches every row — verified with `testTownCenterMarketRowsTakeFocus`; the walk found Down could not reach Other goods from Sell 5, fixed by making the button full width
