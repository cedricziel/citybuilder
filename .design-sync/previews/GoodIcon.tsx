import { GoodIcon, goods, goodName } from "@citybuilder/ui";

export const AllGoods = () => (
  <div style={{ display: "flex", flexWrap: "wrap", gap: 12, maxWidth: 560 }}>
    {goods.map((good) => (
      <div key={good} style={{ display: "flex", flexDirection: "column", alignItems: "center", gap: 4, width: 84 }}>
        <GoodIcon good={good} size={48} />
        <span className="cb-caption2 cb-secondary">{goodName(good)}</span>
      </div>
    ))}
  </div>
);

export const HUDSizes = () => (
  <div style={{ display: "flex", alignItems: "flex-end", gap: 16 }}>
    <GoodIcon good="bread" size={14} />
    <GoodIcon good="bread" size={16} />
    <GoodIcon good="bread" size={24} />
    <GoodIcon good="bread" size={48} />
  </div>
);
