import { Coachmark, WorldBackdrop } from "@citybuilder/ui";

export const FirstRun = () => (
  <WorldBackdrop width={480} height={110} zoom={2}>
    <div style={{ padding: 24, display: "flex", justifyContent: "center" }}>
      <Coachmark />
    </div>
  </WorldBackdrop>
);
