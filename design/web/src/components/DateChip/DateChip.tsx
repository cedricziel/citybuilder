import { Icon } from "../Icon/Icon";
import "./DateChip.css";

export type Season = "spring" | "summer" | "autumn" | "winter";

export interface DateChipProps {
  /** Season and year, "Autumn 1203". */
  date: string;
  /** Picks the glyph. Default `spring`. */
  season?: Season;
}

const symbols = { spring: "camera.macro", summer: "sun.max.fill", autumn: "leaf.fill", winter: "snowflake" } as const;

/**
 * The date on a phone: a 26pt chip with a season glyph and "Autumn 1203",
 * left-aligned under the status pill and level with the first-steps capsule
 * on the right. The pad, Mac and TV pills carry the date themselves. It
 * ignores touches, stays on one line, and the game hides it first when the
 * row is tight (large text, or a screen too narrow to hold it beside the
 * first-steps capsule).
 */
export function DateChip({ date, season = "spring" }: DateChipProps) {
  return (
    <span className="cb-date-chip" aria-label={`Date: ${date}`}>
      <Icon name={symbols[season]} size={12} />
      <span>{date}</span>
    </span>
  );
}
