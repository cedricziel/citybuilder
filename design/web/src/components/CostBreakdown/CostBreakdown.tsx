import { Glass } from "../Glass/Glass";
import { GoodChip } from "../GoodChip/GoodChip";
import type { Good } from "../GoodIcon/GoodIcon";
import "./CostBreakdown.css";

export interface CostLine {
  good: Good;
  need: number;
  have: number;
  /** `ok`, `queueable` (orange) or `blocked` (red). Default: `ok` when have >= need, else `blocked`. */
  status?: "ok" | "queueable" | "blocked";
}

export interface CostBreakdownProps {
  /** One line per required good. Empty -> renders nothing (roads, demolish, inspect). */
  lines: CostLine[];
}

/** Materials the armed building needs, as `have/need` chips on an 8px glass strip. */
export function CostBreakdown({ lines }: CostBreakdownProps) {
  if (lines.length === 0) return null;
  return (
    <Glass radius={8} padding="6px 12px" className="cb-cost" aria-label="Materials needed">
      {lines.map((line) => (
        <GoodChip
          key={line.good}
          good={line.good}
          need={line.need}
          have={line.have}
          status={line.status ?? (line.have >= line.need ? "ok" : "blocked")}
        />
      ))}
    </Glass>
  );
}
