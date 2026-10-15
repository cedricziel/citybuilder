## ADDED Requirements

### Requirement: Stop cues need no bus

A cue whose `action` is `stop` plays nothing, so it MAY leave out `bus`. Every other cue MUST name its bus. The shipped bindings MUST decode against the shipped manifest.

#### Scenario: Shipped bindings decode with bus-less stop cues
- **WHEN** the shipped `bindings.json`, whose `productionStalled` stop cues have no `bus`, is loaded against the shipped manifest
- **THEN** it decodes, and its stop cues have the `stop` action

#### Scenario: A start cue without a bus is rejected
- **WHEN** a start cue in a bindings document leaves out `bus`
- **THEN** decoding fails

### Requirement: A broken audio document is reported

When the bundle holds `manifest.json` or `bindings.json` but the file fails to load, `AudioBundleLoader` SHALL report the error, as a fault in the system log by default, and then fall back to an empty document. A missing file SHALL fall back silently, as before.

#### Scenario: A broken bindings file is reported
- **WHEN** the bundle's `bindings.json` has a start cue without a bus
- **THEN** the loader reports one error naming `bindings.json` and returns empty bindings
