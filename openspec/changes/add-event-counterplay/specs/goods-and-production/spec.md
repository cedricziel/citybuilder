## ADDED Requirements

### Requirement: Herbs

The goods catalog SHALL include herbs (unit bunches, base price 5), which the town market SHALL sell up to 10 and buy up to 20 a season. Herbs SHALL be no house tier's need.

#### Scenario: Buying herbs

- **WHEN** the player buys 5 herbs at the town market in a season in which none were bought
- **THEN** the treasury pays 5 × 150% of the base price, rounded as for other goods, and the town center holds 5 more herbs

### Requirement: Granaries are drawn from last

Every draw of a good from the player's stores (house consumption, porters, producer inputs, construction materials, market sales and order dispatch) SHALL take from stores other than granaries first, in its usual order, and from a granary only when those stores together hold none of the good. Where no granary exists, every draw SHALL behave as before.

#### Scenario: Houses eat from the warehouse first

- **WHEN** a house draws 1 food on a network with a warehouse holding 3 food and a granary holding 20
- **THEN** the warehouse holds 2 food and the granary holds 20

#### Scenario: The granary feeds the town in a shortage

- **WHEN** a house draws 1 food on a network whose only food is 20 in a granary
- **THEN** the granary holds 19 food

### Requirement: Crop fields are marked in the game data

A building item MAY set `crop: true`. The farm, the grain farm and each culture's crop field (hop garden, vineyard, tea garden, coffee grove) SHALL set it; no other building SHALL. Only crop fields SHALL be slowed by blight.

#### Scenario: The sheep farm is not a crop

- **WHEN** a sheep farm stands in a blighted area through the blight season
- **THEN** it completes cycles at its normal rate
