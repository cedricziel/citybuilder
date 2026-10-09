import type { CSSProperties, ReactNode } from "react";
import "../../styles/tokens.css";
import "../../styles/base.css";

export interface CityProviderProps {
  /** System appearance. `dark` switches every `--cb-*` token to its dark value. */
  theme?: "light" | "dark";
  /**
   * Paint a background: `plain` is the system background, `grouped` the
   * grouped-list gray behind sheets. Omit for a transparent root (HUD
   * pieces over a `WorldBackdrop`).
   */
  background?: "plain" | "grouped";
  style?: CSSProperties;
  className?: string;
  children?: ReactNode;
}

/**
 * Root of every Citybuilder screen: sets the `--cb-*` tokens, the system
 * font and the light or dark appearance. Nest a second provider to switch
 * the theme of one subtree.
 */
export function CityProvider({ theme = "light", background, style, className, children }: CityProviderProps) {
  const classes = [
    "cb-root",
    `cb-theme-${theme}`,
    background ? "cb-root--fill" : "",
    background === "grouped" ? "cb-root--grouped" : "",
    className ?? "",
  ]
    .filter(Boolean)
    .join(" ");
  return (
    <div className={classes} data-cb-theme={theme} style={style}>
      {children}
    </div>
  );
}
