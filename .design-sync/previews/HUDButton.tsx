import { HUDButton, HUDButtonCluster, WorldBackdrop } from "@citybuilder/ui";

export const Cluster = () => (
  <WorldBackdrop width={200} height={120} zoom={2}>
    <div style={{ padding: 16, display: "flex", justifyContent: "flex-end" }}>
      <HUDButtonCluster />
    </div>
  </WorldBackdrop>
);

export const Sandbox = () => (
  <WorldBackdrop width={200} height={120} zoom={2}>
    <div style={{ padding: 16, display: "flex", justifyContent: "flex-end" }}>
      <HUDButtonCluster showGoals={false} />
    </div>
  </WorldBackdrop>
);

export const Single = () => (
  <WorldBackdrop width={200} height={80} zoom={2}>
    <div style={{ padding: 16 }}>
      <HUDButton icon="book.fill" label="Research" />
    </div>
  </WorldBackdrop>
);
