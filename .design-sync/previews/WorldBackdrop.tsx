import { WorldBackdrop } from "@citybuilder/ui";

export const Island = () => <WorldBackdrop width={800} height={420} />;

export const Autumn = () => <WorldBackdrop width={800} height={360} season="autumn" zoom={2} />;

export const WinterSelected = () => (
  <WorldBackdrop width={800} height={360} season="winter" zoom={2} selected={{ x: 4, y: 5 }} center={{ x: 6, y: 6 }} />
);

export const LivedIn = () => (
  <WorldBackdrop
    width={800}
    height={360}
    zoom={3}
    center={{ x: 9.5, y: 10 }}
    units={[
      { unit: "walker", x: 7, y: 9, facing: "se" },
      { unit: "woman", x: 8, y: 9, facing: "sw" },
      { unit: "carrier", load: "logs", x: 9, y: 8.4, facing: "sw" },
      { unit: "carrier", load: "sack", x: 9, y: 9.3, facing: "nw" },
      { unit: "cow", x: 11.6, y: 10.4, facing: "sw" },
      { unit: "sheep", x: 12.2, y: 9.6, facing: "se" },
      { unit: "hen", x: 7.6, y: 10.6 },
      { unit: "ship", x: 13.4, y: 12.6, heading: "w" },
    ]}
  />
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
