import "./StatBadge.css";

export interface StatBadgeProps {
  /** Caption, drawn uppercased in caption2 secondary: "Money", "Population", "Island". */
  label: string;
  /** The value in title3 semibold monospaced: "$1,250", "Pop. 84", "Greenhold". */
  value: string;
}

/** One HUD statistic: an uppercase caption over a monospaced value. */
export function StatBadge({ label, value }: StatBadgeProps) {
  return (
    <div className="cb-stat">
      <div className="cb-stat__label">{label.toUpperCase()}</div>
      <div className="cb-stat__value">{value}</div>
    </div>
  );
}
