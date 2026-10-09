import { Glass } from "../Glass/Glass";
import "./PerfOverlay.css";

export interface PerfOverlayProps {
  tickCount: number;
  /** Last tick's wall-clock time in ms. Green under 5 ms, red at 5 or more. Omit before the first tick. */
  tickMs?: number;
}

/** The debug overlay showing the tick counter and per-tick cost. */
export function PerfOverlay({ tickCount, tickMs }: PerfOverlayProps) {
  return (
    <Glass radius={6} padding={6} className="cb-perf">
      <div>tick {tickCount}</div>
      {tickMs !== undefined ? (
        <div style={{ color: tickMs < 5 ? "var(--cb-green)" : "var(--cb-red)" }}>{tickMs.toFixed(2)} ms/tick</div>
      ) : null}
    </Glass>
  );
}
