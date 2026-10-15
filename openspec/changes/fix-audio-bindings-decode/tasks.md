## 1. Decode the shipped bindings

- [x] 1.1 Tests first: the shipped bindings load against the shipped manifest; a start cue without a bus is rejected; a broken bindings file is reported
- [x] 1.2 Stop cues decode without a bus; the lumberjack cues use `lumberjack-hut`
- [x] 1.3 `AudioBundleLoader` reports a present-but-broken manifest or bindings file as a fault
