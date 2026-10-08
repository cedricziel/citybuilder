## ADDED Requirements

### Requirement: Houses render their tier

The world snapshot SHALL report each house's tier. The renderer MUST draw a peasant house with `building-house`, a citizen house with `building-house-tier2` and a merchant house with `building-house-tier3`, and MUST swap the sprite when the tier changes.

#### Scenario: Merchant house uses the tier 3 sprite

- **WHEN** the renderer builds the sprite for an operational house whose snapshot tier is merchants
- **THEN** the node's texture is `building-house-tier3`

#### Scenario: Tier change swaps the house sprite

- **WHEN** a house's tier changes between two snapshots
- **THEN** the reconciler replaces that house's node
