import { StocksTray, WorldBackdrop } from "@citybuilder/ui";

const stocks = [
  { good: "wood" as const, count: 42 },
  { good: "planks" as const, count: 18 },
  { good: "food" as const, count: 31 },
  { good: "grain" as const, count: 12 },
  { good: "flour" as const, count: 6 },
  { good: "bread" as const, count: 9 },
  { good: "hops" as const, count: 4 },
  { good: "beer" as const, count: 2 },
];

export const SixColumns = () => (
  <WorldBackdrop width={800} height={150} zoom={2}>
    <div style={{ padding: 16 }}>
      <StocksTray island="Greenhold" stocks={stocks} columns={6} />
    </div>
  </WorldBackdrop>
);

export const Phone = () => (
  <WorldBackdrop width={420} height={170} zoom={2}>
    <div style={{ padding: 8 }}>
      <StocksTray island="Greenhold" stocks={stocks} columns={3} />
    </div>
  </WorldBackdrop>
);
