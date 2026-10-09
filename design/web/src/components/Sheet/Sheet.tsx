import type { CSSProperties, ReactNode } from "react";
import { Button } from "../Button/Button";
import "./Sheet.css";

export interface SheetProps {
  /** Navigation title, drawn as a large title ("Goals", "Research"). Omit for a bare sheet. */
  title?: string;
  /** The confirmation button top-right. Default "Done"; `null` hides it. */
  doneLabel?: string | null;
  onDone?: () => void;
  /** `grouped` (gray, for lists) or `plain` (white, for dialogs). Default `grouped`. */
  background?: "grouped" | "plain";
  /** Width in px. Default 100% of the parent. */
  width?: number;
  /** Height in px; content scrolls past it. Default auto. */
  height?: number;
  style?: CSSProperties;
  children?: ReactNode;
}

/**
 * An iOS sheet with a `NavigationStack` bar: large title and a bold "Done".
 * The goals, research, pause and new-game views all present in one.
 */
export function Sheet({ title, doneLabel = "Done", onDone, background = "grouped", width, height, style, children }: SheetProps) {
  return (
    <div className={`cb-sheet cb-sheet--${background}`} style={{ width, height, ...style }}>
      <div className="cb-sheet__grabber" />
      {title || doneLabel ? (
        <div className="cb-sheet__bar">
          {doneLabel ? (
            <Button variant="borderless" onClick={onDone} style={{ fontWeight: 600 }}>
              {doneLabel}
            </Button>
          ) : null}
        </div>
      ) : null}
      {title ? <h1 className="cb-sheet__title">{title}</h1> : null}
      <div className="cb-sheet__body">{children}</div>
    </div>
  );
}
