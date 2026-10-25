## MODIFIED Requirements

### Requirement: iPhone "compact play" defaults
On iPhone, the default UX SHALL bias toward short sessions: a new game starts zoomed out to 0.55 so the town center shows a third of the screen wide with open ground and the coast around it, tap-to-inspect with bottom sheets, hidden advanced controls behind a "More" menu. Every other device SHALL start at zoom 1.0. Full functionality MUST remain reachable.

#### Scenario: iPhone short-session defaults
- **WHEN** the app launches on iPhone
- **THEN** the default camera zoom is lower than the iPad default and advanced controls are collapsed

#### Scenario: A phone starts zoomed out
- **WHEN** a new game starts on a phone
- **THEN** the camera zoom is between 0.5 and 0.6

#### Scenario: Other devices keep the default zoom
- **WHEN** a new game starts on an iPad, a Mac or an Apple TV
- **THEN** the camera zoom is 1.0

#### Scenario: New game starts at the device zoom on the town center
- **WHEN** a new game starts at zoom 0.55
- **THEN** the camera still centers on the home town center

## ADDED Requirements

### Requirement: Pinch-to-zoom hint
On a touch device, the first game screen of a new game SHALL show a banner titled "Pinch to zoom" once per install, through the session banner. A loaded save SHALL NOT show it.

#### Scenario: Pinch hint is offered once
- **WHEN** the hint is asked for twice on the same device
- **THEN** the first time shows it and the second does not

#### Scenario: Pinch hint shows as a banner that expires
- **WHEN** the pinch hint shows and the banner's ticks pass
- **THEN** the banner is gone

### Requirement: HUD chrome caps Dynamic Type
The HUD's chrome (the status pill, the More and menu buttons, the First steps capsule, the coachmark, the build bar and its drawer tiles, the tool strip and the date chip) SHALL stop growing at the `accessibility1` text size. Icon buttons SHALL NOT scale with the text. One-line labels SHALL shrink and then truncate rather than wrap, and a word MUST NOT break across lines. Sheets and panels SHALL keep scaling with the text.

#### Scenario: Chrome stays on screen at the largest text
- **WHEN** the text size is accessibility 5 on an iPhone in portrait
- **THEN** the More button, the First steps capsule and the coachmark keep their `accessibility1` size, and no word in them breaks

### Requirement: Building-problem hint
When a building of the player's has shown a status icon with the same problem for 100 ticks, the session SHALL show a banner titled "<Building> has a problem" with the problem text and "Tap the building for details.", once no other banner shows. Each distinct problem text SHALL be named once per session.

#### Scenario: A standing problem names the building
- **WHEN** a farm with no road has stood for 100 ticks
- **THEN** the banner reads "Farm has a problem" with "No road: connect it to a road. Tap the building for details."

#### Scenario: A problem that clears is not named
- **WHEN** the farm gets its road before 100 ticks pass
- **THEN** no problem banner shows

#### Scenario: Each problem is named once
- **WHEN** the banner has shown and expired
- **THEN** the same problem does not raise it again

### Requirement: Touch placement hint
On a phone or an iPad, the tool strip's hint for a building other than a road SHALL read "Tap to position, then tap ✓ to place". A road's hint SHALL read "Tap or drag to place road". The Mac and Apple TV hints do not change.

#### Scenario: A road hint keeps tap or drag on touch
- **WHEN** the road tool is armed on a phone
- **THEN** the hint reads "Tap or drag to place road"

### Requirement: Road callout keeps off neighbours
When the callout of a selected road would cover a building within three tiles, it SHALL move to the opposite side or to a side of the road that covers none; when no side is clear it SHALL keep its usual side. On a phone the callout is 264 points wide.

#### Scenario: Callout keeps off a neighbouring building
- **WHEN** the road's usual callout side covers a farm and the opposite side is clear
- **THEN** the callout takes the opposite side

#### Scenario: Callout keeps its usual side when no side is clear
- **WHEN** every side of the road would cover a building
- **THEN** the callout keeps its usual side

### Requirement: Phone date chip
A phone SHALL show the date in a 26-point chip with a season glyph under the status pill, at the left edge. The chip SHALL give way first: it is hidden at the `accessibility1` text size and above, and on a screen too narrow to hold it beside the First steps capsule.

#### Scenario: The date chip yields when the row is tight
- **WHEN** the text size is accessibility 1 or larger, or the width cannot hold the chip beside the capsule
- **THEN** the chip is hidden

#### Scenario: The date chip shows a glyph for the season
- **WHEN** the season is autumn
- **THEN** the chip's glyph is a leaf, and each of the four seasons has its own

### Requirement: Landscape drawer clears the status pill
On a screen shorter than 500 points, an open build drawer SHALL start below the top bar and its tiles SHALL scroll in the height that is left, at least 96 points.

#### Scenario: A drawer on a short screen leaves room for the status pill
- **WHEN** the drawer opens on a 402-point-tall screen
- **THEN** its tile area is shorter than the usual 280 points
