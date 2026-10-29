## 1. Animated title screen

- [x] 1.1 Tests first: translate the `platform-shells` scenarios for the title backdrop, menu entrance and button feedback into failing CityUI tests; confirm red
- [x] 1.2 `WorldSnapshot.camera` and `tickCount` become settable in CityCore
- [x] 1.3 `TitleBackdropMotion`, `MenuEntrance` and `TitleMenuButtonStyle` to green
- [x] 1.4 `TitleBackdrop` view: build the island off the main thread, fade it in, fall back to a gradient without a renderer
- [x] 1.5 Wire the backdrop, scrim, entrance and button styles into `TitleScreenView`, keeping the Apple TV focus behaviour
- [x] 1.6 Check the title screen in the Mac app: the island draws behind the menu and the camera drifts (frames 45 s apart differ); the iOS and Apple TV builds compile
