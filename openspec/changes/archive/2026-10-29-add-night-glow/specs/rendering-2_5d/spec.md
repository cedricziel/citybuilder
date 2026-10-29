## ADDED Requirements

### Requirement: Fire trades glow at night

Every working fire trade with its sprite on screen SHALL show a warm, additive glow at its hearth. The fire trades are the bakery, smelter, toolsmith and charcoal burner, and "working" is the rule from "Chimneys smoke". The hearth positions are measured on the sprites. The glow's alpha SHALL be the night's darkness over `nightDarkness`, so there is none by day. The glow SHALL flicker slowly, unless Reduce Motion is on.

#### Scenario: Working forge glows at night
- **WHEN** a player toolsmith with no issue is on screen at midnight
- **THEN** its node has a fire-glow child with alpha 1

#### Scenario: Cold forge stays dark
- **WHEN** the same toolsmith lacks iron
- **THEN** its node has no fire-glow child

#### Scenario: No glow by day
- **WHEN** a working toolsmith is on screen at midday
- **THEN** it has no visible fire glow

### Requirement: Lit windows follow the lights art

From dusk to dawn, a building that is inhabited (a house) or working (any other kind) SHALL light its windows. For any other kind, working means a player building with no issue, or a rival's operational building. The building SHALL show the first of `<sprite stem>-lights-<n>` and `<sprite stem>-lights` the atlas has, additively over its sprite, with alpha 0.85 times the darkness over `nightDarkness`; `n` comes from a hash of the building's id, so a building keeps its variant and a row built in order does not cycle through them. Without either, a house SHALL show its two warm panes and other kinds nothing. From 2:00 to 4:30, four houses in five SHALL go dark, fading over a quarter hour at either end; workshops stay lit.

#### Scenario: Lights mask replaces the panes
- **WHEN** the atlas has `building-house-lights` and an inhabited house is drawn at midnight
- **THEN** its window glow is that texture at alpha 0.85 instead of two panes

#### Scenario: Each house shows its own evening
- **WHEN** the atlas has the lights variants of `building-house` and a row of inhabited houses is drawn at midnight
- **THEN** each house shows the variant its id hashes to, the same every frame, and the row spreads across all three

#### Scenario: Late at night most houses go to bed
- **WHEN** a town is drawn at 3 AM
- **THEN** about four houses in five show no window glow, and a working bakery is still lit
