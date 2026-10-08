## ADDED Requirements

### Requirement: The world is in an age

The world SHALL be in one of five ages — Antiquity, Medieval, Renaissance, Industrial, Modern — in that order. Each age SHALL have a start year: 500 BC, 1200, 1450, 1780 and 1910. A world created without a choice SHALL be Medieval.

#### Scenario: Default age is medieval

- **WHEN** a new game is created without an age
- **THEN** the world's age is Medieval

#### Scenario: Snapshot carries the age

- **WHEN** a snapshot is taken of an Industrial world
- **THEN** the snapshot's age is Industrial

#### Scenario: Years before Christ

- **WHEN** a date in year −499 is shown
- **THEN** its text reads "500 BC" with the season in front

### Requirement: The player chooses the starting age

A new game started in an age SHALL be in that age, start its calendar in spring of the age's start year, and have researched Scholarship, every tech of earlier ages and every era tech up to that age.

#### Scenario: Start in the Renaissance

- **WHEN** a new game is created in the Renaissance
- **THEN** its date is spring 1450, Milling, Feudal Order and Printing Press are researched, and Steam Power is not

#### Scenario: Start in Antiquity

- **WHEN** a new game is created in Antiquity
- **THEN** its date is spring 500 BC and Milling is not researched

### Requirement: Era techs advance the age

Researching an era tech SHALL move the world into the age it opens and emit an `ageAdvanced` world event. If the current year is before the new age's start year, the calendar SHALL jump forward so the current year is that start year; otherwise the date SHALL be unchanged.

#### Scenario: Feudal Order opens the Medieval age

- **WHEN** an Antiquity world completes Feudal Order
- **THEN** its age is Medieval, the tick's events include `ageAdvanced(medieval)`, and its year is 1200

#### Scenario: Calendar never goes back

- **WHEN** a world dated 1500 completes Printing Press
- **THEN** its year is still 1500

### Requirement: Obsolete buildings

A building kind made obsolete by a tech SHALL be rejected for placement with `obsolete(tech)` once that tech is researched. Buildings already placed SHALL keep working.

#### Scenario: Windmill replaces the quern house

- **WHEN** Milling is researched
- **THEN** placing a quern house is rejected as obsolete by Milling, and an existing quern house keeps producing flour

#### Scenario: Quern house in Antiquity

- **WHEN** an Antiquity world places a quern house with grain supplied
- **THEN** it produces 1 flour from 2 grain every 80 ticks
