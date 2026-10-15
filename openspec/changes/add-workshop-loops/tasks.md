## 1. Loops per building

- [x] 1.1 Tests first: the new `audio-playback` scenarios as failing CityAudio tests
- [x] 1.2 `DispatchedCue.entity`, the coordinator's stop handler, `LoopSelection`, and the entity-keyed `EngineCuePlayer`
- [x] 1.3 `AudioStack` wiring: stop handler and listener updates

## 2. Workshop sounds

- [x] 2.1 Recipes for the fields, mill, oven, forge, mine, brewing vat and shipwright loops; `make audio`
- [x] 2.2 Bindings for every producing kind: start on `productionCycleCompleted` and `productionResumed`, stop on `productionStalled`
- [x] 1.4 Stop cues may leave out `bus`, so the shipped bindings decode; fix the lumberjack filter to the raw value `lumberjack-hut`
