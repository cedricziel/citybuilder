## ADDED Requirements

### Requirement: New Game offers map size and island count

In Sandbox mode the New Game dialog SHALL show a "Map" menu picker under the layout picker, with Classic, Small, Medium and Large, Medium selected by default, and a hint line under it: "Classic is the same map in every game. Small, Medium and Large grow new islands from the seed." With the Archipelago layout and a map other than Classic, the dialog SHALL also show an "Islands" menu picker with 3, 4, 5, 6 and 7, 5 selected by default. Classic SHALL start the classic map of the chosen layout; Small, Medium and Large SHALL start a generated map of that size with the chosen island count, or one island for Single Island. In Scenario mode the Map picker SHALL show Classic and be disabled, its hint SHALL read "Scenarios are played on the classic map.", the Islands picker SHALL be hidden, and the committed world SHALL use the classic map; the sandbox choice SHALL come back on switching to Sandbox. The dialog SHALL open, and reset on cancel, with a random seed. Every new line SHALL have a German translation: "Karte", "Klassisch", "Klein", "Mittel", "Groß", "Inseln", "Klassisch ist in jedem Spiel dieselbe Karte. Klein, Mittel und Groß lassen aus dem Seed neue Inseln wachsen." and "Szenarien werden auf der klassischen Karte gespielt."

#### Scenario: Map choice reaches the world

- **WHEN** the player picks Archipelago, Large and 6 islands with custom seed 12 and starts
- **THEN** the committed world is a generated archipelago with a 360-tile side, 6 islands and seed 12

#### Scenario: Classic starts the classic map

- **WHEN** the player picks Single Island and Classic with the Default seed and starts
- **THEN** the committed world's terrain equals that of a new classic single-island game with seed 0

#### Scenario: Islands picker only for a generated archipelago

- **WHEN** the dialog shows Single Island, then Archipelago with Classic, then Archipelago with Medium
- **THEN** the Islands picker is hidden, hidden, then shown

#### Scenario: Scenario mode locks the map to Classic

- **WHEN** the player picks Large in Sandbox mode, switches to Scenario mode and starts First Harvest
- **THEN** the Map picker shows Classic and is disabled, the committed world uses the classic map, and switching back to Sandbox shows Large again

#### Scenario: The dialog opens with a random seed

- **WHEN** the New Game dialog opens, and again after it is cancelled
- **THEN** the seed mode is Random with a captured seed, and the map is Medium with 5 islands

#### Scenario: Map labels are translated

- **WHEN** the dialog is shown in German
- **THEN** the Map picker reads "Karte" with "Klassisch", "Klein", "Mittel" and "Groß", and the Islands picker reads "Inseln"
