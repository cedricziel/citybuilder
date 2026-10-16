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

From dusk to dawn, a building that is inhabited (a house) or working (any other kind) SHALL light its windows. For any other kind, working means a player building with no issue, or a rival's operational building. When the atlas has `<sprite stem>-lights`, the building SHALL show that texture additively over its sprite, with alpha equal to the darkness over `nightDarkness`. Without it, a house SHALL show its two warm panes and other kinds nothing.

#### Scenario: Lights mask replaces the panes
- **WHEN** the atlas has `building-house-lights` and an inhabited house is drawn at midnight
- **THEN** its window glow is that texture at alpha 1 instead of two panes
