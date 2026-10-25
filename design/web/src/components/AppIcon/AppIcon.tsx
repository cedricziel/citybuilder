import type { CSSProperties } from "react";
import { appIconSprite } from "../../generated/brand";

export interface AppIconProps {
  /** Rendered size in px. The source is the 256 px macOS icon. Default 128. */
  size?: number;
  style?: CSSProperties;
}

/**
 * The app icon, Citybuilder's brand mark: the citizen's gable house from
 * IsoKit, close up on a grass plot under an afternoon sky, with smoke from
 * its chimney, in the macOS rounded square. Rendered by
 * `scripts/art/app_icon.py`; use it as is, never redraw or recolor it.
 */
export function AppIcon({ size = 128, style }: AppIconProps) {
  return <img src={appIconSprite} alt="Citybuilder" width={size} height={size} style={{ display: "block", ...style }} />;
}
