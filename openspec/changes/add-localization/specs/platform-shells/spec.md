## MODIFIED Requirements

### Requirement: Touch placement hint
On a phone or an iPad, the tool strip's hint for a building other than a road SHALL read "Tap to position, then tap ✓ to place". When the hint ends with the count a lumberjack hut's or forester's site would reach, it SHALL read "Tap to position" before the count, so the line fits a 375-point phone in English and German. A road's hint SHALL read "Tap or drag to place road". The Mac and Apple TV hints do not change.

#### Scenario: A road hint keeps tap or drag on touch
- **WHEN** the road tool is armed on a phone
- **THEN** the hint reads "Tap or drag to place road"

#### Scenario: A hut's hint is short enough for its count
- **WHEN** a lumberjack hut is armed on a phone at a site that reaches 9 trees
- **THEN** the hint reads "Tap to position · 9 trees in reach"
