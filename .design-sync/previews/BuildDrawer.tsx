import { BuildDrawer, WorldBackdrop, gatherDrawerTiles } from "@citybuilder/ui";

const OnMap = ({ children }: { children: React.ReactNode }) => (
  <WorldBackdrop width={460} height={340} zoom={2}>
    <div style={{ position: "absolute", left: 16, top: 16 }}>{children}</div>
  </WorldBackdrop>
);

export const Gather = () => (
  <OnMap>
    <BuildDrawer category="Gather" tiles={gatherDrawerTiles} />
  </OnMap>
);

export const ArmedLumberjack = () => (
  <OnMap>
    <BuildDrawer category="Gather" tiles={gatherDrawerTiles} armed="Lumberjack" />
  </OnMap>
);

export const Craft = () => (
  <OnMap>
    <BuildDrawer
      category="Craft"
      tiles={[
        { label: "Sawmill", art: "sawmill", cost: 120 },
        { label: "Bakery", art: "bakery", cost: 90 },
        { label: "Quern House", art: "quern-house", cost: 60 },
        { label: "Windmill", art: "windmill", cost: 110, needs: "Milling" },
        { label: "Charcoal", art: "charcoal-burner", cost: 70, needs: "Mining" },
        { label: "Smelter", art: "smelter", cost: 150, needs: "Metallurgy" },
        { label: "Weaver", art: "weaver", cost: 120, needs: "Weaving" },
      ]}
    />
  </OnMap>
);
