import { WorldBackdrop } from "@citybuilder/ui";

export const Island = () => <WorldBackdrop width={800} height={420} />;

export const Autumn = () => <WorldBackdrop width={800} height={360} season="autumn" zoom={2} />;

export const WinterSelected = () => (
  <WorldBackdrop width={800} height={360} season="winter" zoom={2} selected={{ x: 4, y: 5 }} center={{ x: 6, y: 6 }} />
);
