import { ShipSprite, WorldBackdrop, type ShipHeading } from "@citybuilder/ui";

const headings: ShipHeading[] = ["n", "ne", "e", "se", "s", "sw", "w", "nw"];

export const Headings = () => (
  <div style={{ display: "flex", flexWrap: "wrap", gap: 12, maxWidth: 640 }}>
    {headings.map((heading) => (
      <div key={heading} style={{ display: "flex", flexDirection: "column", alignItems: "center", gap: 4 }}>
        <ShipSprite heading={heading} />
        <span className="cb-caption2 cb-mono cb-secondary">{heading}</span>
      </div>
    ))}
  </div>
);

export const AtSea = () => (
  <WorldBackdrop
    width={460}
    height={220}
    zoom={2}
    center={{ x: 13, y: 13 }}
    buildings={[]}
    units={[
      { unit: "ship", x: 13, y: 13, heading: "sw" },
      { unit: "ship", x: 15, y: 12, heading: "e" },
    ]}
  />
);
