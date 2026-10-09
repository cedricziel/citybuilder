import type { CSSProperties, ReactNode } from "react";
import { Icon, type IconName } from "../Icon/Icon";
import "./Button.css";

export interface ButtonProps {
  /**
   * SwiftUI button style: `borderedProminent` (filled accent, the one main
   * action), `bordered` (tinted gray fill), `borderless` (accent text) or
   * `plain` (label color, no chrome).
   */
  variant?: "borderedProminent" | "bordered" | "borderless" | "plain";
  /** `regular` (default) or `large` (title-screen buttons, 280px max). */
  size?: "small" | "regular" | "large";
  /** `destructive` paints the label (or fill) red, like `role: .destructive`. */
  role?: "destructive";
  /** Optional leading SF Symbol. */
  icon?: IconName;
  disabled?: boolean;
  /** Stretch to the container width (up to `maxWidth`). */
  fullWidth?: boolean;
  onClick?: () => void;
  style?: CSSProperties;
  children?: ReactNode;
}

/** A SwiftUI `Button` in one of the system styles. */
export function Button({
  variant = "bordered",
  size = "regular",
  role,
  icon,
  disabled,
  fullWidth,
  onClick,
  style,
  children,
}: ButtonProps) {
  const classes = [
    "cb-button",
    `cb-button--${variant}`,
    `cb-button--${size}`,
    role === "destructive" ? "cb-button--destructive" : "",
    fullWidth ? "cb-button--full" : "",
  ]
    .filter(Boolean)
    .join(" ");
  return (
    <button type="button" className={classes} disabled={disabled} onClick={onClick} style={style}>
      {icon ? <Icon name={icon} size={size === "small" ? 13 : 17} /> : null}
      {children}
    </button>
  );
}
