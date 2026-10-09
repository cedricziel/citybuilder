import { SegmentedPicker, CityProvider } from "@citybuilder/ui";

export const Two = () => (
  <div style={{ width: 360 }}>
    <SegmentedPicker label="Mode" options={["Sandbox", "Scenario"]} selected="Sandbox" />
  </div>
);

export const Three = () => (
  <div style={{ width: 360 }}>
    <SegmentedPicker label="Difficulty" options={["Easy", "Normal", "Hard"]} selected="Hard" />
  </div>
);

export const Dark = () => (
  <CityProvider theme="dark" background="plain" style={{ padding: 16, borderRadius: 12, width: 392 }}>
    <SegmentedPicker label="Seed" options={["Default", "Random", "Custom"]} selected="Random" />
  </CityProvider>
);
