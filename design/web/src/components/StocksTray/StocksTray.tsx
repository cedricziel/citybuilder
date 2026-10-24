import { Glass } from "../Glass/Glass";
import { GoodChip } from "../GoodChip/GoodChip";
import { goodName, type Good } from "../GoodIcon/GoodIcon";
import "./StocksTray.css";

export interface StockLine {
  good: Good;
  count: number;
}

export interface StocksTrayProps {
  /** The island's name, for the caption: "GREENHOLD STOCKS · 6 GOODS". */
  island: string;
  /** Every good the island holds, in catalog order. Empty -> renders nothing. */
  stocks: StockLine[];
  /** Columns of 96pt chips: at most 3 on a phone and 6 elsewhere, fewer to fit beside the minimap. Default 3. */
  columns?: number;
}

/** The current island's stocks, dropped down from the status pill's island button. */
export function StocksTray({ island, stocks, columns = 3 }: StocksTrayProps) {
  if (stocks.length === 0) return null;
  const count = Math.max(1, Math.min(columns, stocks.length));
  return (
    <Glass radius={12} padding="10px 14px" className="cb-stocks" aria-label="Island stocks">
      <div className="cb-stocks__caption">
        {island} stocks · {stocks.length} goods
      </div>
      <div className="cb-stocks__grid" style={{ gridTemplateColumns: `repeat(${count}, 96px)` }}>
        {stocks.map((stock) => (
          <span key={stock.good} className="cb-stocks__item">
            <GoodChip good={stock.good} count={stock.count} />
            <span className="cb-stocks__name">{goodName(stock.good)}</span>
          </span>
        ))}
      </div>
    </Glass>
  );
}
