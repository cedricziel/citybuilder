import { Inspector, WorldBackdrop } from "@citybuilder/ui";

const OnMap = ({ children, h = 300 }: { children: React.ReactNode; h?: number }) => (
  <WorldBackdrop width={460} height={h} zoom={2}>
    <div style={{ position: "absolute", left: 16, bottom: 16, right: 16 }}>{children}</div>
  </WorldBackdrop>
);

export const House = () => (
  <OnMap>
    <Inspector
      lines={[
        "Kind: house",
        "Anchor: (12, 9)",
        "Footprint: 2×2",
        "State: operational",
        "Build: ready",
        "Road: connected",
        "Tier: Citizens",
        "Residents: 6/8",
        "Needs: food ✓ · planks ✓ · beer ✗",
        "Ingrid · Citizens · wants beer",
        "Henrik · Citizens · wants beer",
      ]}
    />
  </OnMap>
);

export const UnderConstruction = () => (
  <OnMap h={200}>
    <Inspector lines={["Kind: sawmill", "Anchor: (7, 4)", "Footprint: 2×2", "State: constructing", "Build: 14/40 ticks", "Road: none"]} />
  </OnMap>
);

export const Gallery = () => (
  <OnMap h={220}>
    <Inspector
      lines={["Kind: gallery", "State: operational", "Road: connected", "Commission: none"]}
      commission={{ title: "Commission art — $400", enabled: true }}
    />
  </OnMap>
);

export const Caravanserai = () => (
  <OnMap h={200}>
    <Inspector
      lines={["Kind: caravanserai", "State: operational", "Road: connected"]}
      exportPicker={{ options: ["None", "Tea", "Coffee", "Wine"], selected: "Tea" }}
    />
  </OnMap>
);
