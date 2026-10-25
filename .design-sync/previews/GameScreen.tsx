import { GameScreen, GoalsPanel, StandingsPanel, gatherDrawerTiles } from "@citybuilder/ui";

const W = 860;
const H = 600;

export const Inspecting = () => (
  <GameScreen
    width={W}
    height={H}
    world={{ selected: { x: 3, y: 6 } }}
    inspector={{
      lines: ["Kind: house", "State: operational", "Road: connected", "Tier: Peasants", "Residents: 4/6", "Needs: food ✓", "Next: Citizens need planks"],
    }}
  />
);

export const GatherDrawer = () => (
  <GameScreen width={W} height={H} drawer={{ category: "Gather", tiles: gatherDrawerTiles }} />
);

export const PlacingHouse = () => (
  <GameScreen
    width={W}
    height={H}
    tool={{
      tool: "House",
      art: "house",
      cost: 50,
      hint: "Tap or drag to place house",
      materials: [{ good: "planks", have: 18, need: 4 }],
    }}
    placing={{ art: "house", valid: true }}
  />
);

const catchment = (() => {
  const tiles = [];
  for (let y = 1; y <= 8; y++) for (let x = 1; x <= 8; x++) if (Math.abs(x - 4.5) + Math.abs(y - 4.5) <= 4) tiles.push({ x, y });
  return tiles;
})();

export const PlacingLumberjack = () => (
  <GameScreen
    width={W}
    height={H}
    tool={{ tool: "Lumberjack", art: "lumberjack-hut", cost: 80, hint: "Tap or drag to place lumberjack · 3 trees in reach" }}
    placing={{ art: "lumberjack-hut", valid: true, count: { text: "3 trees in reach", tone: "low" }, area: { tiles: catchment } }}
  />
);

export const StocksAndFirstSteps = () => (
  <GameScreen width={W} height={H} stocksOpen firstSteps={{ ledger: { tax: 8, upkeep: 24 } }} />
);

export const DeficitHint = () => (
  <GameScreen
    width={W}
    height={H}
    paused
    banner={{
      title: "In the red: upkeep $24 vs tax $8",
      description: "Residents pay tax only when fed. Build a farm, fill your houses, and sell surplus at the town center's market.",
      onResume: () => {},
    }}
  />
);

export const MacRejection = () => (
  <GameScreen
    width={W}
    height={H}
    device="mac"
    rejection="Needs a road"
    tool={{ tool: "Sawmill", art: "sawmill", cost: 120, hint: "Click or drag to place sawmill", materials: [{ good: "wood", have: 2, need: 4 }] }}
    world={{ season: "autumn" }}
  />
);

export const PortraitDock = () => (
  <GameScreen width={430} height={H + 60} device="phone" drawer={{ category: "Gather", tiles: gatherDrawerTiles }} />
);

export const Rivals = () => (
  <GameScreen
    width={W}
    height={H}
    menu={{ standings: true, routes: true }}
    sheet={
      <StandingsPanel
        rows={[
          { name: "You", colour: "player", population: "84", age: "Medieval", wealth: "$1,250", player: true },
          { name: "Ravenmoor", colour: "crimson", population: "62", age: "Medieval", wealth: "$940" },
          { name: "Saltmere", colour: "azure", population: "40", age: "Antiquity", wealth: "$610" },
        ]}
      />
    }
  />
);

export const GoalsSheet = () => (
  <GameScreen
    width={W}
    height={H}
    sheet={<GoalsPanel goals={[{ text: "Residents 32/40", met: false }, { text: "Bread 20/20", met: true }]} />}
  />
);
