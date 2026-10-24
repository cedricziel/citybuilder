import { WorldBackdrop } from "@citybuilder/ui";

export const Island = () => <WorldBackdrop width={800} height={420} />;

export const Autumn = () => <WorldBackdrop width={800} height={360} season="autumn" zoom={2} />;

export const WinterSelected = () => (
  <WorldBackdrop width={800} height={360} season="winter" zoom={2} selected={{ x: 4, y: 5 }} center={{ x: 6, y: 6 }} />
);

export const Night = () => <WorldBackdrop width={800} height={360} night zoom={2} center={{ x: 6, y: 8 }} />;

/** A lumberjack's catchment round (11, 9): the gold ring on the ground, trees in reach brightened. */
const reach = (() => {
  const tiles = [];
  for (let y = 6; y <= 12; y++) for (let x = 8; x <= 14; x++) if (Math.abs(x - 11) + Math.abs(y - 9) <= 4) tiles.push({ x, y });
  return tiles;
})();

export const AreaOfEffect = () => (
  <WorldBackdrop
    width={800}
    height={360}
    zoom={2}
    center={{ x: 11, y: 9 }}
    area={{ tiles: reach }}
    buildings={[
      { art: "town-center", x: 6, y: 6 },
      { art: "lumberjack-hut", x: 10, y: 8, ghost: true },
    ]}
  />
);
