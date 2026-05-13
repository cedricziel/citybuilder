## ADDED Requirements

### Requirement: ESC and Cmd-. toggle pause across platforms

On every platform with a hardware keyboard (Mac, iPad with Smart Keyboard or Bluetooth, iPhone with Bluetooth), pressing **ESC** SHALL toggle `session.isPaused`. Pressing **Cmd-.** (Cmd-Period) is an alias on every platform. The same shortcuts MUST close the pause menu when it is open (universal "back out" semantics).

This requirement fulfills the existing Mac "Pause hotkey" requirement (the `simulation toggles between paused and running` scenario) and extends it to iPad / iPhone where a hardware keyboard is attached.

#### Scenario: ESC toggles pause on Mac

- **WHEN** the player presses ESC while a game is running on Mac
- **THEN** `session.isPaused` becomes `true` and the pause menu appears

- **WHEN** the player presses ESC while the pause menu is showing on Mac
- **THEN** `session.isPaused` becomes `false` and the menu dismisses

#### Scenario: Cmd-Period also toggles pause on Mac

- **WHEN** the player presses Cmd-. on Mac
- **THEN** the pause state toggles exactly as if ESC had been pressed

#### Scenario: ESC toggles pause on iPad with a hardware keyboard

- **WHEN** the player presses ESC on an iPad with a Smart Keyboard attached
- **THEN** the pause state toggles exactly as on Mac

#### Scenario: iPhone with a Bluetooth keyboard responds to ESC

- **WHEN** the player presses ESC on an iPhone with a Bluetooth keyboard attached
- **THEN** the pause state toggles exactly as on Mac

#### Scenario: HUD pause button works without a keyboard

- **WHEN** the player is on an iPad or iPhone with no hardware keyboard attached and taps the HUD pause button
- **THEN** the pause state toggles regardless of keyboard presence
