import { useState } from "react";
import { Glass } from "../Glass/Glass";
import type { Good } from "../GoodIcon/GoodIcon";
import "./MarketPanel.css";

export interface MarketRow {
  good: Good;
  /** "Wood — buy $6 (10 left) · sell $2 (20 left)"; a side the market doesn't trade is left out. */
  text: string;
  /** The market sells this good: the row offers Buy 1 and Buy 5. */
  buyable?: boolean;
  /** The market buys it: Sell 1 and Sell 5. */
  sellable?: boolean;
  /** Buy is possible now (stock left, room in the warehouse, money). Default true. */
  canBuy?: boolean;
  /** Sell is possible now (stock left, the island holds some). Default true. */
  canSell?: boolean;
}

export interface MarketPanelProps {
  /** Goods the market sells, the island holds or produces, or traded this season. */
  rows: MarketRow[];
  /** Goods the market only buys and the island can't use, collapsed under "Other goods (n)". */
  otherRows?: MarketRow[];
  /** Start with the other goods shown. Default false. */
  showOtherGoods?: boolean;
  /** Draw it on its own glass card; inside the inspector callout it sits bare. Default true. */
  framed?: boolean;
  onTrade?: (direction: "buy" | "sell", good: Good, quantity: 1 | 5) => void;
}

/**
 * The town center's market, in the inspector callout: each good's prices
 * and what is left this season, with Buy 1, Buy 5, Sell 1 and Sell 5.
 */
export function MarketPanel({ rows, otherRows = [], showOtherGoods = false, framed = true, onTrade }: MarketPanelProps) {
  const [others, setOthers] = useState(showOtherGoods);
  const body = (
    <div className="cb-market">
      <div className="cb-market__header">Market</div>
      {rows.map((row) => (
        <Row key={row.good} row={row} onTrade={onTrade} />
      ))}
      {otherRows.length > 0 ? (
        <button type="button" className="cb-market__others" aria-expanded={others} onClick={() => setOthers(!others)}>
          {others ? "Hide other goods" : `Other goods (${otherRows.length})`}
        </button>
      ) : null}
      {others ? otherRows.map((row) => <Row key={row.good} row={row} onTrade={onTrade} />) : null}
    </div>
  );
  return framed ? (
    <Glass radius={10} padding={12} style={{ display: "inline-block" }}>
      {body}
    </Glass>
  ) : (
    body
  );
}

function Row({ row, onTrade }: { row: MarketRow; onTrade?: MarketPanelProps["onTrade"] }) {
  const button = (direction: "buy" | "sell", quantity: 1 | 5, enabled: boolean) => (
    <button
      type="button"
      key={`${direction}${quantity}`}
      className="cb-market__button"
      disabled={!enabled}
      onClick={() => onTrade?.(direction, row.good, quantity)}
    >
      {direction === "buy" ? "Buy" : "Sell"} {quantity}
    </button>
  );
  return (
    <div className="cb-market__row">
      <div className="cb-market__text">{row.text}</div>
      <div className="cb-market__buttons">
        {row.buyable ? [button("buy", 1, row.canBuy ?? true), button("buy", 5, row.canBuy ?? true)] : null}
        {row.sellable ? [button("sell", 1, row.canSell ?? true), button("sell", 5, row.canSell ?? true)] : null}
      </div>
    </div>
  );
}

/** A young town's market: wood, planks and food to buy and sell; spices only bought. */
export const sampleMarketRows: MarketRow[] = [
  { good: "wood", text: "Wood — buy $6 (10 left) · sell $2 (20 left)", buyable: true, sellable: true },
  { good: "planks", text: "Planks — buy $14 (8 left) · sell $5 (16 left)", buyable: true, sellable: true, canSell: false },
  { good: "food", text: "Food — buy $8 (12 left) · sell $3 (20 left)", buyable: true, sellable: true, canBuy: false },
  { good: "bread", text: "Bread — sell $9 (10 left)", sellable: true },
];
