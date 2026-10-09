import { GoodIcon, goodName, type Good } from "../GoodIcon/GoodIcon";
import "./GoodChip.css";

export interface GoodChipProps {
  good: Good;
  /** The stock count (HUD stocks row). Ignored when `need` is set. */
  count?: number;
  /** Cost mode: how many the armed building needs; the chip reads `have/need`. */
  need?: number;
  /** Cost mode: how many the island holds. */
  have?: number;
  /**
   * Cost mode color: `ok` (label color), `queueable` (orange, a carrier can
   * still bring it) or `blocked` (red). Default `ok`.
   */
  status?: "ok" | "queueable" | "blocked";
}

/**
 * A good's pixel icon with a monospaced number: a stock count in the HUD
 * (16px icon, caption) or `have/need` in the cost breakdown (14px, caption2).
 */
export function GoodChip({ good, count, need, have, status = "ok" }: GoodChipProps) {
  const cost = need !== undefined;
  const text = cost ? `${have ?? 0}/${need}` : `${count ?? 0}`;
  return (
    <span
      className={`cb-good-chip ${cost ? "cb-good-chip--cost" : ""} cb-good-chip--${cost ? status : "ok"}`}
      aria-label={`${goodName(good)} ${text}`}
    >
      <GoodIcon good={good} size={cost ? 14 : 16} />
      <span className="cb-good-chip__count">{text}</span>
    </span>
  );
}
