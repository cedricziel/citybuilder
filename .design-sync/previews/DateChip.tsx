import { DateChip, WorldBackdrop } from "@citybuilder/ui";

const OnMap = ({ children }: { children: React.ReactNode }) => (
  <WorldBackdrop width={460} height={90} zoom={2}>
    <div style={{ padding: 24, display: "flex", gap: 12, justifyContent: "center" }}>{children}</div>
  </WorldBackdrop>
);

export const Seasons = () => (
  <OnMap>
    <DateChip date="Spring 1203" season="spring" />
    <DateChip date="Summer 1203" season="summer" />
    <DateChip date="Autumn 1203" season="autumn" />
    <DateChip date="Winter 1203" season="winter" />
  </OnMap>
);
