## ADDED Requirements

### Requirement: Game over stops player commands

Once the game is over, the world SHALL drop every player command (placing, demolishing, clearing forest, choosing research, route commands, commissions and export choices) when it is applied. A dropped command MUST NOT change the world and MUST NOT emit a world event. Rival placements SHALL still apply. The world MUST stay encodable so a lost game can still be saved and loaded.

#### Scenario: Placement after game over is dropped

- **WHEN** the player places a building on a free tile after the game is over
- **THEN** no building is added, the balance is unchanged and the tick emits no `buildingPlaced` or `placementRejected` event

#### Scenario: Demolish after game over is dropped

- **WHEN** the player demolishes one of their buildings after the game is over
- **THEN** the building is still there and the tick emits no `buildingDemolished` event

#### Scenario: Lost game still saves

- **WHEN** a world whose game is over is encoded and decoded
- **THEN** the decoded world is still over and equals the original
