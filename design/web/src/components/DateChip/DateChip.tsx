import { Icon } from "../Icon/Icon";
import "./DateChip.css";

export type Season = "spring" | "summer" | "autumn" | "winter";

const seasons: readonly string[] = ["spring", "summer", "autumn", "winter"];

/** The season a date such as "Autumn 1203" starts with, or undefined when it is not one of the four. */
export function seasonOf(date: string): Season | undefined {
  const word = date.trim().split(/\s+/)[0]?.toLowerCase() ?? "";
  return seasons.includes(word) ? (word as Season) : undefined;
}

export interface DateChipProps {
  /** Season and year, "Autumn 1203". */
  date: string;
  /** Picks the glyph; none when omitted. */
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
export function DateChip({ date, season }: DateChipProps) {
  // The date only changes with the season, about once a minute, and the game never announces it:
  // a status role names the chip for assistive tech while `aria-live="off"` keeps it quiet.
  return (
    <span className="cb-date-chip" role="status" aria-live="off" aria-label={`Date: ${date}`}>
      {season ? <Icon name={symbols[season]} size={12} /> : null}
      <span>{date}</span>
    </span>
  );
}
