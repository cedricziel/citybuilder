## 1. Mac input

- [x] 1.1 Tests-first: translate the `platform-shells` scenarios of this change into failing CityUI tests; confirm red
- [x] 1.2 Implement to green: `GameSession.zoom(by:aroundScreenOffset:)`, `MacMapInput`, `CityRootView.stepBack` and `GameMenuCommand`
- [x] 1.3 Wire the macOS event monitor into `CityRootView` and `GameCommands` into the Mac app; give sheets' close buttons Esc
- [ ] 1.4 Build the Mac app and try Esc, trackpad, mouse and keys by hand; build iOS and tvOS — all three build; the hand check is still open
- [x] 1.5 Run `SCENARIO_COVERAGE_STRICT=1 make test-scenarios` and confirm no uncovered scenario from this change
