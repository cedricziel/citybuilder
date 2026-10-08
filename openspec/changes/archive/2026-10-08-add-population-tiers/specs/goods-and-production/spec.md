## ADDED Requirements

### Requirement: Bakery turns food into bread

The goods catalog SHALL include `bread`. The production catalog MUST include a recipe for the `bakery` building kind that consumes 2 food and produces 1 bread every 50 ticks. Bakeries are supplied with food by buffer-to-producer carriers like any producer with inputs.

#### Scenario: Bakery bakes bread from food

- **WHEN** an operational bakery holds 2 food and 50 ticks pass with room in its output stockpile
- **THEN** it holds 1 bread and no food
