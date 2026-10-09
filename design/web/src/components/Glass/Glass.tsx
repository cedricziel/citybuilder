import type { CSSProperties, ElementType, ReactNode } from "react";
import "./Glass.css";

export interface GlassProps {
  /**
   * The SwiftUI shape behind `.background(.thinMaterial, in: ...)`:
   * `rounded` (a continuous rounded rectangle, see `radius`), `capsule` or `circle`.
   */
  shape?: "rounded" | "capsule" | "circle";
  /** Corner radius for `shape="rounded"`. The app uses 6, 8, 10 and 12. Default 12. */
  radius?: 6 | 8 | 10 | 12;
  /** CSS padding. Default none; HUD panels pass e.g. `"8px 16px"`. */
  padding?: CSSProperties["padding"];
  /** Element to render. Default `div`. */
  as?: ElementType;
  style?: CSSProperties;
  className?: string;
  children?: ReactNode;
}

/**
 * The thin-material surface every HUD piece sits on: a translucent, blurred
 * panel over the world map. Use it for any new floating panel so it matches
 * the HUD, palette and inspector.
 */
export function Glass({ shape = "rounded", radius = 12, padding, as: Tag = "div", style, className, children }: GlassProps) {
  const classes = ["cb-glass", `cb-glass--${shape}`, className ?? ""].filter(Boolean).join(" ");
  return (
    <Tag className={classes} style={{ borderRadius: shape === "rounded" ? radius : undefined, padding, ...style }}>
      {children}
    </Tag>
  );
}
