import { HUDFrame, WorldBackdrop } from "@citybuilder/ui";

const stocks = [
  { good: "wood", count: 42 },
  { good: "planks", count: 18 },
  { good: "food", count: 31 },
  { good: "grain", count: 12 },
  { good: "flour", count: 6 },
  { good: "bread", count: 9 },
  { good: "ore", count: 4 },
  { good: "tools", count: 2 },
] as const;

const OnMap = ({ children, season }: { children: React.ReactNode; season?: "summer" | "autumn" | "winter" }) => (
  <WorldBackdrop width={760} height={130} zoom={2} season={season}>
    <div style={{ padding: 16, display: "flex" }}>{children}</div>
  </WorldBackdrop>
);

export const Island = () => (
  <OnMap>
    <HUDFrame date="Spring 1203" money="$1,250" population="Pop. 84" island="Greenhold" stocks={[...stocks]} />
  </OnMap>
);

export const Night = () => (
  <OnMap season="winter">
    <HUDFrame date="Winter 498 BC" timeOfDay="night" money="$310" population="Pop. 22" island="Stonehaven" stocks={[{ good: "wood", count: 8 }, { good: "food", count: 3 }]} />
  </OnMap>
);

export const OverWater = () => (
  <OnMap>
    <HUDFrame date="Autumn 1781" timeOfDay="dusk" money="-$40" population="Pop. 312" />
  </OnMap>
);
