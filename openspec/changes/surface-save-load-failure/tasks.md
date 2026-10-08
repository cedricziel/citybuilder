## 1. Surface load failures on the title screen

- [ ] 1.1 Tests-first: translate `#### Scenario: Undecodable save shows a load-failure alert` and `#### Scenario: New Game still works after a failed load` into failing swift-testing tests in `TitleScreenViewModelTests` (a stub facade that throws the error `SaveStore.decode` gives for corrupt JSON). Confirm red.
- [ ] 1.2 Implement to green: store the error in `TitleScreenViewModel.loadFailure`, log it with `os.Logger`, and present an alert from `TitleScreenView`.
- [ ] 1.3 Run `make lint && make format`.
