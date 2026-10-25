import { StatusPill, WorldBackdrop } from "@citybuilder/ui";

const OnMap = ({ children }: { children: React.ReactNode }) => (
  <WorldBackdrop width={600} height={80} zoom={2}>
    <div style={{ padding: 15, display: "flex", justifyContent: "center" }}>{children}</div>
  </WorldBackdrop>
);

export const Pad = () => (
  <OnMap>
    <StatusPill date="Spring 1203" money="$1,250" population="84" island="Greenhold" speed={1} />
  </OnMap>
);

export const PausedAtNight = () => (
  <OnMap>
    <StatusPill date="Winter 1204" timeOfDay="night" money="-$40" population="62" island="Greenhold" paused stocksOpen />
  </OnMap>
);

export const Mac = () => (
  <OnMap>
    <StatusPill device="mac" date="Autumn 498 BC" timeOfDay="dusk" money="$3,410" population="156" island="Kallisto" speed={3} />
  </OnMap>
);

export const Phone = () => (
  <OnMap>
    <StatusPill device="phone" money="$1,250" population="84" island="Greenhold" speed={2} />
  </OnMap>
);
