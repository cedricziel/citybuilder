import "./AreaCountCapsule.css";

export type AreaCountTone = "neutral" | "low" | "none";

export interface AreaCountCapsuleProps {
  /** "18 trees in reach", "3 trees in reach", "No trees in reach", "Mine site: 4 rock tiles". */
  text: string;
  /**
   * How worried to look: `neutral` regular material (enough to work with),
   * `low` amber (fewer than 5, the building will soon idle), `none` red
   * (nothing in reach; placing stays allowed). Default `neutral`.
   */
  tone?: AreaCountTone;
  /** Mac draws it a size smaller (12pt). Default `touch` (13pt). */
  device?: "touch" | "mac";
}

/** Whether a catchment count reads `neutral`, `low` or `none`: below 5 is low. */
export function areaCountTone(count: number): AreaCountTone {
  if (count === 0) return "none";
  return count < 5 ? "low" : "neutral";
}

/**
 * What the ghost's site reaches, in a semibold capsule just above the
 * ghost's roof that moves with it, while the gold ring marks the area on
 * the ground.
 */
export function AreaCountCapsule({ text, tone = "neutral", device = "touch" }: AreaCountCapsuleProps) {
  return (
    <span className={`cb-area-count cb-area-count--${tone} cb-area-count--${device}`} role="status">
      {text}
    </span>
  );
}
