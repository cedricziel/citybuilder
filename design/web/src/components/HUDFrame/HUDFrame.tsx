import { Glass } from "../Glass/Glass";
import { Icon } from "../Icon/Icon";
import { StatBadge } from "../StatBadge/StatBadge";
import { GoodChip } from "../GoodChip/GoodChip";
import type { Good } from "../GoodIcon/GoodIcon";
import "./HUDFrame.css";

export interface HUDStock {
  good: Good;
  count: number;
}

export interface HUDFrameProps {
  /** Season and year, e.g. "Spring 1203" or "Autumn 498 BC". Hidden when empty. */
  date?: string;
  /** Time of day; picks the symbol next to the date. Default `day`. */
  timeOfDay?: "dawn" | "day" | "dusk" | "night";
  /** Formatted balance, e.g. "$1,250" or "-$40". */
  money: string;
  /** Formatted population, e.g. "Pop. 84". */
  population: string;
  /** Name of the island under the camera; omit over open water before any island was seen. */
  island?: string;
  /** Island stocks, shown as a scrolling chip row under the stats when `island` is set. */
  stocks?: HUDStock[];
}

const symbols = {
  dawn: "sunrise.fill",
  day: "sun.max.fill",
  dusk: "sunset.fill",
  night: "moon.stars.fill",
} as const;

/**
 * The top-left HUD panel: date, money, population, island name and the
 * island's stock row on a 12px thin-material card. It stretches to the
 * available width; the HUD buttons sit to its right.
 */
export function HUDFrame({ date, timeOfDay = "day", money, population, island, stocks = [] }: HUDFrameProps) {
  return (
    <Glass radius={12} padding="8px 16px" className="cb-hud">
      {date ? (
        <div className="cb-hud__date">
          <Icon name={symbols[timeOfDay]} size={12} />
          <span>{date}</span>
        </div>
      ) : null}
      <div className="cb-hud__stats">
        <StatBadge label="Money" value={money} />
        <StatBadge label="Population" value={population} />
        {island ? <StatBadge label="Island" value={island} /> : null}
      </div>
      {island && stocks.length > 0 ? (
        <div className="cb-hud__stocks" aria-label="Island stocks">
          {stocks.map((stock) => (
            <GoodChip key={stock.good} good={stock.good} count={stock.count} />
          ))}
        </div>
      ) : null}
    </Glass>
  );
}
