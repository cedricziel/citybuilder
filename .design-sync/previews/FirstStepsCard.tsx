import { FirstStepsCard, WorldBackdrop, defaultFirstSteps } from "@citybuilder/ui";

const OnMap = ({ children, h = 500 }: { children: React.ReactNode; h?: number }) => (
  <WorldBackdrop width={460} height={h} zoom={2}>
    <div style={{ position: "absolute", top: 16, right: 16 }}>{children}</div>
  </WorldBackdrop>
);

export const InTheRed = () => (
  <OnMap>
    <FirstStepsCard ledger={{ tax: 8, upkeep: 24 }} />
  </OnMap>
);

export const TwoStepsMet = () => (
  <OnMap>
    <FirstStepsCard
      ledger={{ tax: 36, upkeep: 24 }}
      steps={defaultFirstSteps.map((step, index) => ({ ...step, met: index < 2 }))}
    />
  </OnMap>
);

export const CollapsedCapsule = () => (
  <OnMap h={80}>
    <FirstStepsCard collapsed ledger={{ tax: 8, upkeep: 24 }} steps={defaultFirstSteps.map((step, index) => ({ ...step, met: index < 2 }))} />
  </OnMap>
);
