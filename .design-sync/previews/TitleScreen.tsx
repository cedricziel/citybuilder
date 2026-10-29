import { TitleScreen, CityProvider } from "@citybuilder/ui";

export const WithSave = () => (
  <div style={{ width: 800, height: 520 }}>
    <TitleScreen continueSave="Greenhold — Spring 1206" />
  </div>
);

export const FirstLaunch = () => (
  <div style={{ width: 800, height: 460 }}>
    <TitleScreen />
  </div>
);

export const MacDark = () => (
  <CityProvider theme="dark" style={{ width: 800, height: 560 }}>
    <TitleScreen continueSave="Stonehaven — Winter 498 BC" showQuit />
  </CityProvider>
);

export const WithCampaigns = () => (
  <div style={{ width: 800, height: 580 }}>
    <TitleScreen continueSave="The Guild Charter — Spring 1205" showCampaigns />
  </div>
);
