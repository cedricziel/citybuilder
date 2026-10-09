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

export const Monument = () => (
  <OnMap>
    <SessionBanner title="The monument is complete" description="Taxes rise by 10%." />
  </OnMap>
);
