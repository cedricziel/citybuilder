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
