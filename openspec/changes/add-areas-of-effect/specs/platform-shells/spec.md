## ADDED Requirements

### Requirement: Count capsule over the ghost

While a lumberjack hut, forester or mine ghost stands where it could be placed, the HUD SHALL show a capsule centred just above the ghost's roof, moving with it: "N trees in reach" for a hut, "N open grass in reach" for a forester, and "Mine site: N rock tiles" for a mine, with N the mountain tiles under its plot. A hut's or forester's capsule SHALL be neutral glass at 5 or more, amber at 1 to 4, and red at 0; it warns and never blocks placement. Its type SHALL be 13 points on touch devices, 12 points on the Mac and 24 points on Apple TV. The capsule SHALL NOT show for a ghost that could not be placed there, nor for a selected building, whose count the inspector shows.

#### Scenario: Enough trees reads neutral
- **WHEN** a lumberjack hut ghost could be placed where 18 trees are in reach
- **THEN** the capsule reads "18 trees in reach" in the neutral tone

#### Scenario: Few trees read amber
- **WHEN** the ghost's site has 3 trees in reach
- **THEN** the capsule reads "3 trees in reach" in the amber tone

#### Scenario: No trees read red
- **WHEN** the ghost's site has no trees in reach
- **THEN** the capsule reads "No trees in reach" in the red tone, and the ghost may still be placed

#### Scenario: Mine site count
- **WHEN** a mine ghost stands on a valid plot with 4 rock tiles
- **THEN** the capsule reads "Mine site: 4 rock tiles"

#### Scenario: Apple TV type size
- **WHEN** the capsule shows on Apple TV
- **THEN** its text is 24 points
