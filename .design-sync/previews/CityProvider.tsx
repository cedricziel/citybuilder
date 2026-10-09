import { CityProvider, Button, SegmentedPicker } from "@citybuilder/ui";

const Body = () => (
  <div style={{ display: "flex", flexDirection: "column", gap: 12, padding: 20, width: 320 }}>
    <div className="cb-headline">Greenhold</div>
    <div className="cb-footnote cb-secondary">A medieval town of 84 people.</div>
    <SegmentedPicker options={["Easy", "Normal", "Hard"]} selected="Normal" />
    <div style={{ display: "flex", gap: 8 }}>
      <Button variant="borderedProminent">Start</Button>
      <Button variant="bordered">Cancel</Button>
    </div>
  </div>
);

export const Light = () => (
  <CityProvider theme="light" background="plain" style={{ borderRadius: 12 }}>
    <Body />
  </CityProvider>
);

export const Dark = () => (
  <CityProvider theme="dark" background="plain" style={{ borderRadius: 12 }}>
    <Body />
  </CityProvider>
);

export const GroupedBackground = () => (
  <CityProvider background="grouped" style={{ borderRadius: 12 }}>
    <Body />
  </CityProvider>
);
