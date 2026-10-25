import { SessionBanner, WorldBackdrop } from "@citybuilder/ui";

const OnMap = ({ children }: { children: React.ReactNode }) => (
  <WorldBackdrop width={460} height={110} zoom={2}>
    <div style={{ padding: "16px 24px", display: "flex", justifyContent: "center" }}>{children}</div>
  </WorldBackdrop>
);

export const NewAge = () => (
  <OnMap>
    <SessionBanner title="The Renaissance age begins" description="Printing, trade and tall stuccoed fronts." />
  </OnMap>
);

export const FuelOut = () => (
  <OnMap>
    <SessionBanner title="Steam engine is out of coal" description="Its effects stop until carriers bring more." />
  </OnMap>
);

export const IdleGood = () => (
  <OnMap>
    <SessionBanner title="Nothing uses your planks" description="Build a house for it, or sell planks at the town center's market." />
  </OnMap>
);

export const DeficitHint = () => (
  <WorldBackdrop width={460} height={170} zoom={2}>
    <div style={{ padding: "16px 24px", display: "flex", justifyContent: "center" }}>
      <SessionBanner
        title="In the red: upkeep $24 vs tax $8"
        description="Residents pay tax only when fed. Build a farm, fill your houses, and sell surplus at the town center's market."
        onResume={() => {}}
      />
    </div>
  </WorldBackdrop>
);

export const Monument = () => (
  <OnMap>
    <SessionBanner title="The monument is complete" description="Taxes rise by 10%." />
  </OnMap>
);
