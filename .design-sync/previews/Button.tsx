import { Button } from "@citybuilder/ui";

const row = { display: "flex", gap: 12, alignItems: "center", flexWrap: "wrap" } as const;

export const Styles = () => (
  <div style={row}>
    <Button variant="borderedProminent">Start</Button>
    <Button variant="bordered">New Game…</Button>
    <Button variant="borderless">Re-roll</Button>
    <Button variant="plain">Quit to Title</Button>
  </div>
);

export const WithIcon = () => (
  <div style={row}>
    <Button variant="bordered" icon="ellipsis.circle">Actions</Button>
    <Button variant="borderedProminent" icon="play.fill">Resume</Button>
  </div>
);

export const Sizes = () => (
  <div style={row}>
    <Button variant="borderedProminent" size="small">Got it</Button>
    <Button variant="borderedProminent">Keep Playing</Button>
    <Button variant="bordered" size="large" style={{ width: 280 }}>Settings</Button>
  </div>
);

export const States = () => (
  <div style={row}>
    <Button variant="borderedProminent" disabled>Start</Button>
    <Button variant="borderless" size="small" disabled>Commission art — $400</Button>
    <Button variant="bordered" role="destructive">Quit</Button>
  </div>
);
