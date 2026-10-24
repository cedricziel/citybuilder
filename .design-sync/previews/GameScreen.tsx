import { GameScreen, GoalsPanel } from "@citybuilder/ui";

export const Inspecting = () => (
  <GameScreen
    width={800}
    height={480}
    world={{ selected: { x: 3, y: 6 } }}
    inspector={{
      lines: ["Kind: house", "State: operational", "Road: connected", "Tier: Peasants", "Residents: 4/6", "Needs: food ✓ · planks ✗"],
    }}
  />
);

export const PlacingHouse = () => (
  <GameScreen
    width={800}
    height={480}
    armed="House"
    armedCaption="Tap or drag to place house — $120"
    cost={[{ good: "planks", have: 18, need: 4 }, { good: "wood", have: 42, need: 2 }]}
    placing={{ art: "house", valid: true }}
  />
);

export const FirstSteps = () => (
  <GameScreen width={860} height={620} firstSteps={{ ledger: { tax: 8, upkeep: 24 } }} />
);

const catchment = (() => {
  const tiles = [];
  for (let y = 1; y <= 8; y++) for (let x = 1; x <= 8; x++) if (Math.abs(x - 4.5) + Math.abs(y - 4.5) <= 4) tiles.push({ x, y });
  return tiles;
})();

export const PlacingLumberjack = () => (
  <GameScreen
    width={800}
    height={600}
    armed="Lumberjack"
    armedCaption="Tap or drag to place lumberjack — $80"
    placing={{ art: "lumberjack-hut", valid: true, count: { text: "3 trees in reach", tone: "low" }, area: { tiles: catchment } }}
  />
);

export const DeficitHint = () => (
  <GameScreen
    width={800}
    height={480}
    banner={{
      title: "In the red: upkeep $24 vs tax $8",
      description: "Residents pay tax only when fed. Build a farm, fill your houses, and sell surplus at the town center's market.",
      onResume: () => {},
    }}
  />
);

export const Announcement = () => (
  <GameScreen
    width={800}
    height={480}
    rejection="Needs a road"
    banner={{ title: "The Renaissance age begins", description: "Printing, trade and tall stuccoed fronts." }}
    coachmark
    world={{ season: "autumn" }}
  />
);

export const GoalsSheet = () => (
  <GameScreen
    width={800}
    height={480}
    sheet={<GoalsPanel goals={[{ text: "Residents 32/40", met: false }, { text: "Bread 20/20", met: true }]} />}
  />
);
