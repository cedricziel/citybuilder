## ADDED Requirements

### Requirement: Base prices for culture goods

Every good SHALL have a base price. The culture goods SHALL cost $3 for hops, grapes, tea leaves and coffee cherries, and $16 for beer, wine, tea and coffee. The other goods SHALL keep the prices of the base price table: wood $4, planks $8, food $4, bread $12, grain $3, flour $6, ore $5, charcoal $5, iron $14, tools $30.

#### Scenario: Wine price

- **WHEN** the base price of wine is read
- **THEN** it is 16

#### Scenario: Every good is priced

- **WHEN** the base price of every good in the catalog is read
- **THEN** each is at least 1
