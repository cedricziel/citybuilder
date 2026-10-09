import { GoodChip } from "@citybuilder/ui";

const row = { display: "flex", gap: 12, alignItems: "center" } as const;

export const Stocks = () => (
  <div style={row}>
    <GoodChip good="wood" count={42} />
    <GoodChip good="planks" count={18} />
    <GoodChip good="food" count={31} />
    <GoodChip good="bread" count={9} />
    <GoodChip good="tools" count={0} />
  </div>
);

export const CostStatuses = () => (
  <div style={row}>
    <GoodChip good="planks" have={18} need={4} status="ok" />
    <GoodChip good="wood" have={2} need={6} status="queueable" />
    <GoodChip good="tools" have={0} need={2} status="blocked" />
  </div>
);
