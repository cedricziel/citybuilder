import { Inspector, WorldBackdrop } from "@citybuilder/ui";

const OnMap = ({ children, h = 300 }: { children: React.ReactNode; h?: number }) => (
  <WorldBackdrop width={460} height={h} zoom={2}>
    <div style={{ position: "absolute", left: 16, top: 16 }}>{children}</div>
  </WorldBackdrop>
);

export const House = () => (
  <OnMap h={260}>
    <Inspector
      title="House"
      art="house-tier2"
      tier="Citizens"
      residentsFill={0.75}
      needs={[
        { good: "food", met: true },
        { good: "planks", met: false },
      ]}
      lines={["Residents: 6/8", "Next: Merchants need bread, tools, cloth, beer"]}
    />
  </OnMap>
);

export const NextTier = () => (
  <OnMap h={220}>
    <Inspector
      title="House"
      art="house"
      tier="Peasants"
      residentsFill={0.5}
      needs={[{ good: "food", met: true }]}
      lines={["Residents: 2/4", "Next: Citizens need planks"]}
    />
  </OnMap>
);

export const OutputStuck = () => (
  <OnMap h={240}>
    <Inspector
      title="Bakery"
      art="bakery"
      recipe={{ inputs: [{ good: "flour", amount: 1 }], outputs: [{ good: "bread", amount: 1 }] }}
      lines={["State: operational", "Road: connected"]}
      problem="Output stuck: no room for bread"
    />
  </OnMap>
);

export const Gatherer = () => (
  <OnMap h={220}>
    <Inspector
      title="Lumberjack"
      art="lumberjack-hut"
      recipe={{ inputs: [], outputs: [{ good: "wood", amount: 1 }] }}
      lines={["State: operational", "Road: connected", "Trees in reach: 9"]}
    />
  </OnMap>
);

export const UnderConstruction = () => (
  <OnMap h={220}>
    <Inspector
      title="Sawmill"
      art="sawmill"
      recipe={{ inputs: [{ good: "wood", amount: 1 }], outputs: [{ good: "planks", amount: 1 }] }}
      lines={["State: constructing", "Road: none"]}
      problem="No road: connect it to a road"
    />
  </OnMap>
);

export const Gallery = () => (
  <OnMap h={220}>
    <Inspector
      title="Gallery"
      art="gallery"
      lines={["State: operational", "Road: connected"]}
      commission={{ title: "Commission art — $400", enabled: true }}
    />
  </OnMap>
);

export const Caravanserai = () => (
  <OnMap h={220}>
    <Inspector
      title="Caravanserai"
      art="caravanserai"
      lines={["State: operational", "Road: connected"]}
      exportPicker={{ options: ["None", "Tea", "Coffee", "Wine"], selected: "Tea" }}
    />
  </OnMap>
);
