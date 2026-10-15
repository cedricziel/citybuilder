## ADDED Requirements

### Requirement: Interface sounds are bound by name

`AudioStack.playInterfaceSound(_ name:)` SHALL play a cue bound to the key `ui.<name>` in `bindings.json` as a one-shot. A name without a binding SHALL play nothing. The shipped bindings SHALL bind `ui.tap`, `ui.select`, `ui.toggle`, `ui.open`, `ui.close` and `ui.reject` to generated sounds on the `sfx` bus.

#### Scenario: Interface sounds are bound
- **WHEN** the shipped bindings are loaded
- **THEN** each of `ui.tap`, `ui.select`, `ui.toggle`, `ui.open`, `ui.close` and `ui.reject` has a start cue on the `sfx` bus whose file the generator made

#### Scenario: Interface sound lookup
- **WHEN** an interface sound named `open` is played with bindings that bind `ui.open`, and one named `missing` with no binding
- **THEN** the cue for `ui.open` is chosen, and nothing for `missing`
