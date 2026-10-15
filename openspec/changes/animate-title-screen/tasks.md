## 1. Animated title screen

- [x] 1.1 Tests first: translate the `platform-shells` scenarios for the title backdrop, menu entrance and button feedback into failing CityUI tests; confirm red
- [x] 1.2 `WorldSnapshot.camera` and `tickCount` become settable in CityCore
- [x] 1.3 `TitleBackdropMotion`, `MenuEntrance` and `TitleMenuButtonStyle` to green
- [x] 1.4 `TitleBackdrop` view: build the island off the main thread, fade it in, fall back to a gradient without a renderer
- [x] 1.5 Wire the backdrop, scrim, entrance and button styles into `TitleScreenView`, keeping the Apple TV focus behaviour
- [ ] 1.6 Check the title screen on the simulator (when the slot is free), with Reduce Motion on and off
