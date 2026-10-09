import { GoalsPanel, CityProvider } from "@citybuilder/ui";

export const FirstHarvest = () => (
  <GoalsPanel
    width={390}
    height={300}
    goals={[
      { text: "Residents 32/40", met: false },
      { text: "Bread 20/20", met: true },
    ]}
  />
);

export const GuildTown = () => (
  <GoalsPanel
    width={390}
    height={300}
    goals={[
      { text: "Merchants 30/30", met: true },
      { text: "Tools 30/30", met: true },
      { text: "Reach the Renaissance age", met: false },
    ]}
  />
);

export const Dark = () => (
  <CityProvider theme="dark">
    <GoalsPanel width={390} height={300} goals={[{ text: "Reach the Industrial age", met: false }, { text: "Citizens 60/60", met: true }]} />
  </CityProvider>
);
