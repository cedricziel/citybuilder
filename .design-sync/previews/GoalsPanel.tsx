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

export const Chapter = () => (
  <GoalsPanel
    width={390}
    height={620}
    goals={[
      { text: "Research Metallurgy", met: true },
      { text: "Own a guild hall", met: true },
      { text: "Merchants 14/20", met: false },
      { text: "Tools 20/20", met: true },
    ]}
    deadline={{ label: "Before 1210", remaining: "1 year, 2 seasons left" }}
    bonus={[
      { text: "Merchants 14/30 and tools 20/30", met: false },
      { text: "Hold 20 merchants for a season", met: false },
    ]}
  />
);

export const RivalRace = () => (
  <GoalsPanel
    width={390}
    height={480}
    goals={[{ text: "Reach the Renaissance", met: false }]}
    deadline={{ label: "Before 1212", remaining: "3 years, 1 season left" }}
    race={{ title: "First to the Renaissance", player: "42/60", rival: "Ravenshore", rivalProgress: "50/60", rivalAhead: true }}
    bonus={[{ text: "Earn $800 at rival ports", met: false }]}
  />
);
