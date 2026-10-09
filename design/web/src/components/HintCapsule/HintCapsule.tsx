import type { ReactNode } from "react";
import { Glass } from "../Glass/Glass";
import "./HintCapsule.css";

export interface HintCapsuleProps {
  /** One short line, e.g. "Tap or drag to place house — $120". */
  children: ReactNode;
}

/** The caption2 glass capsule under the palette that says what the armed tool does. */
export function HintCapsule({ children }: HintCapsuleProps) {
  return (
    <Glass shape="capsule" padding="4px 8px" className="cb-hint">
      {children}
    </Glass>
  );
}
