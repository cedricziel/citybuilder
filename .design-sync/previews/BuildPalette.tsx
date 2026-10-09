import { BuildPalette, defaultPaletteTools, WorldBackdrop } from "@citybuilder/ui";

const OnMap = ({ children }: { children: React.ReactNode }) => (
  <WorldBackdrop width={780} height={80} zoom={2}>
    <div style={{ padding: 12 }}>{children}</div>
  </WorldBackdrop>
);

export const Inspect = () => (
  <OnMap>
    <BuildPalette tools={defaultPaletteTools} />
  </OnMap>
);

export const HouseArmed = () => (
  <OnMap>
    <BuildPalette tools={defaultPaletteTools} armed="House" />
  </OnMap>
);

export const LockedArmed = () => (
  <OnMap>
    <BuildPalette tools={defaultPaletteTools.slice(9)} armed="Toolsmith" />
  </OnMap>
);

export const Demolish = () => (
  <OnMap>
    <BuildPalette tools={defaultPaletteTools.slice(0, 6)} armed="Demolish" />
  </OnMap>
);
