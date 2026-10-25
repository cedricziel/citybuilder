import { Minimap, WorldBackdrop, defaultTown } from "@citybuilder/ui";

const OnMap = ({ children }: { children: React.ReactNode }) => (
  <WorldBackdrop width={460} height={180} zoom={2}>
    <div style={{ position: "absolute", right: 16, bottom: 16 }}>{children}</div>
  </WorldBackdrop>
);

export const Pad = () => (
  <OnMap>
    <Minimap camera={{ x: 7, y: 7, tilesAcross: 10 }} ships={[{ x: 13, y: 12 }]} />
  </OnMap>
);

export const WithRivals = () => (
  <OnMap>
    <Minimap
      device="mac"
      buildings={[
        ...defaultTown,
        { art: "house", x: 11, y: 10, owner: "crimson" },
        { art: "warehouse", x: 2, y: 9, owner: "azure" },
      ]}
      ships={[{ x: 13, y: 12 }, { x: 1, y: 3, owner: "azure" }]}
      camera={{ x: 5, y: 6, tilesAcross: 8 }}
    />
  </OnMap>
);

export const Phone = () => (
  <OnMap>
    <Minimap device="phone" camera={{ x: 7, y: 7, tilesAcross: 6 }} />
  </OnMap>
);
