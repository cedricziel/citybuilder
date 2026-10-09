import type { ReactNode } from "react";
import "./InsetList.css";

export interface InsetListProps {
  /** Optional uppercase footnote header over the group. */
  header?: string;
  children?: ReactNode;
}

/** An inset grouped `List` section: a 10px rounded group of `ListRow`s with hairline separators. */
export function InsetList({ header, children }: InsetListProps) {
  return (
    <section className="cb-inset-section">
      {header ? <div className="cb-inset-section__header">{header.toUpperCase()}</div> : null}
      <div className="cb-inset-list">{children}</div>
    </section>
  );
}

export interface ListRowProps {
  /** Disabled rows dim to the secondary label color. */
  disabled?: boolean;
  /** `button` rows draw their text in the accent color, as SwiftUI does for a `Button` in a `List`. */
  button?: boolean;
  onClick?: () => void;
  children?: ReactNode;
}

/** One row of an `InsetList`: 44px minimum height, 16px insets. */
export function ListRow({ disabled, button, onClick, children }: ListRowProps) {
  const classes = ["cb-list-row", button ? "cb-list-row--button" : "", disabled ? "cb-list-row--disabled" : ""].filter(Boolean).join(" ");
  return (
    <div className={classes} role={button ? "button" : undefined} aria-disabled={disabled || undefined} onClick={disabled ? undefined : onClick}>
      {children}
    </div>
  );
}
