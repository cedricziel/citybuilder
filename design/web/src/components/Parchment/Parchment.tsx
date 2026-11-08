import type { CSSProperties, ElementType, ReactNode } from "react";
import "./Parchment.css";

export interface ParchmentProps {
  /** Corner radius. The callout and banners use 10, the drawer 12. Default 10. */
  radius?: 10 | 12 | 14;
  /** CSS padding. Default none. */
  padding?: CSSProperties["padding"];
  /** Element to render. Default `div`. */
  as?: ElementType;
  style?: CSSProperties;
  className?: string;
  children?: ReactNode;
}

/**
 * The paper the panels that describe the town are drawn on: cream paper, a
 * 2pt brown edge and dark ink, the same in light and dark mode. The inspector
 * callout, build drawer, Statistics sheet and banners use it; always-visible
 * controls (rail, pills, HUD buttons) stay on `Glass`. Titles on it take
 * `cb-parchment-title` (serif, bold).
 */
export function Parchment({ radius = 10, padding, as: Tag = "div", style, className, children }: ParchmentProps) {
  const classes = ["cb-parchment", className ?? ""].filter(Boolean).join(" ");
  return (
    <Tag className={classes} style={{ borderRadius: radius, padding, ...style }}>
      {children}
    </Tag>
  );
}
