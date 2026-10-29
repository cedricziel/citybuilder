## 1. Loops per building

- [x] 1.1 Tests first: the new `audio-playback` scenarios as failing CityAudio tests
- [x] 1.2 `DispatchedCue.entity`, the coordinator's stop handler, `LoopSelection`, and the entity-keyed `EngineCuePlayer`
- [x] 1.3 `AudioStack` wiring: stop handler and listener updates
- [x] 1.4 Stop cues may leave out `bus`, so the shipped bindings decode; the lumberjack filter uses the raw value `lumberjack-hut`
- [x] 1.5 `AudioBundleLoader` reports a present-but-broken manifest or bindings file as a fault
- [x] 1.6 `EntityLoopMixer` and `PlayerLoopVoice`: a 3-tile margin before a playing loop is replaced, 0.25 s fades, and generation-guarded re-scheduling
- [x] 1.7 Session end: `AudioCoordinator.endSession()`, `AudioStack.endSession()`, `GameSession.onEnd`, the title screen ending the session it drops, and each app shell wiring `onEnd`

## 2. Workshop sounds

- [x] 2.1 Recipes for the fields, mill, oven, forge, mine, brewing vat and shipwright loops; `make audio`
- [x] 2.2 Bindings for every producing kind: start on `productionCycleCompleted` and `productionResumed`, stop on `productionStalled`
