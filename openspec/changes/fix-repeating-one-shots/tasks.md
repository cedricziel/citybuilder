## 1. One-shots

- [x] 1.1 Failing test first: a burst of 100 identical one-shots in one frame restarts a pool node 100 times
- [x] 1.2 `OneShotLimiter`, with its scenarios as tests, used by `EngineCuePlayer` for every one-shot
- [x] 1.3 One-shots cached as buffers; a running pool node takes the next one-shot with `.interrupts` instead of a stop and a start
- [x] 1.4 `OneShotDriver` drops a one-shot while 4 wait on the node queue, and drops one queued before the engine stopped or restarted

## 2. Voices

- [x] 2.1 `PlayerVoice` start and stop are idempotent; a stopped voice never starts
