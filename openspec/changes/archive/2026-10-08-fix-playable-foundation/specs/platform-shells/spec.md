## ADDED Requirements

### Requirement: Placement rejection feedback

When a placement attempt is rejected, the HUD SHALL show a transient message that names the rejection reason in player language. The message MUST stay visible for 2.5 seconds, and a newer rejection MUST replace an older one. Shortfall messages MUST list each missing good and its quantity.

#### Scenario: Material shortfall message names the missing goods

- **WHEN** a house placement is rejected with `insufficientMaterials([.planks: 2])`
- **THEN** the HUD message reads "Needs 2 more planks"

#### Scenario: Occupied tile message

- **WHEN** a placement is rejected with `tileOccupied`
- **THEN** the HUD message reads "Tile occupied"

#### Scenario: Rejection message expires

- **WHEN** 2.5 seconds pass after a rejection message appears and no new rejection occurs
- **THEN** the HUD shows no rejection message

### Requirement: HUD good icons load from the bundled atlas

The HUD stocks row SHALL show each good's pixel-art icon, resolved from the compiled `Icons` texture atlas in the app bundle. The SF Symbol fallback MUST appear only when a good has no entry in that atlas.

#### Scenario: Bundled good icon resolves from the compiled atlas

- **WHEN** the icon loader resolves `wood` against a bundle that contains a compiled `Icons` atlas with a `good-wood` texture
- **THEN** the loader reports the atlas as its origin, not the fallback

#### Scenario: Missing good icon falls back to the symbol

- **WHEN** the icon loader resolves a good that has no texture in the `Icons` atlas
- **THEN** the loader reports the fallback origin

### Requirement: Compact HUD labels stay on one line

On the compact (iPhone) idiom, HUD stat values, stat captions, and build-palette entry labels SHALL each render on a single line, and money values MUST use locale-grouped digits (for example "$1,000"). A label that does not fit MUST shrink or truncate, never wrap.

#### Scenario: Compact money value uses grouped digits

- **WHEN** the HUD formats a balance of 1000 for the compact idiom in the `en_US` locale
- **THEN** the text is "$1,000"

#### Scenario: Compact layout limits labels to one line

- **WHEN** the compact layout's label configuration is queried
- **THEN** stat values, stat captions, and palette labels each declare a line limit of 1

### Requirement: Build palette lists only player-buildable kinds

The build palette SHALL offer every building kind the player may place, and MUST NOT offer the town center, which world generation seeds for free.

#### Scenario: Palette omits the town center

- **WHEN** the build palette's kind list is queried
- **THEN** it contains house, farm and road, and does not contain the town center
