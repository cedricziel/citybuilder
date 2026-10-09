import { Sheet } from "../Sheet/Sheet";
import { InsetList, ListRow } from "../InsetList/InsetList";
import "./ResearchPanel.css";

export interface ResearchRow {
  /** Tech name: "Milling", "Printing Press". */
  name: string;
  state: "researched" | "inProgress" | "available" | "locked";
  /** Knowledge cost. */
  cost: number;
  /** Knowledge spent so far; only read while `inProgress`. */
  progress?: number;
  /** What it unlocks: "Windmill, Bakery" or "The Renaissance age". */
  unlocks: string;
  /** Prerequisites: "Masonry, 40 citizens". Omit when there are none. */
  requires?: string;
}

export interface ResearchPanelProps {
  techs: ResearchRow[];
  width?: number;
  height?: number;
  onChoose?: (name: string) => void;
  onDone?: () => void;
}

function stateLabel(row: ResearchRow): string {
  switch (row.state) {
    case "researched":
      return "Researched";
    case "inProgress":
      return `${row.progress ?? 0}/${row.cost}`;
    case "available":
      return `${row.cost} knowledge`;
    case "locked":
      return "Locked";
  }
}

/**
 * The research sheet: every tech as a button row. Only `available` rows are
 * tappable (accent text); the rest dim. The tech in progress shows a bar.
 */
export function ResearchPanel({ techs, width, height, onChoose, onDone }: ResearchPanelProps) {
  return (
    <Sheet title="Research" onDone={onDone} width={width} height={height}>
      <InsetList>
        {techs.map((row) => (
          <ListRow key={row.name} button disabled={row.state !== "available"} onClick={() => onChoose?.(row.name)}>
            <div className="cb-tech">
              <div className="cb-tech__head">
                <span className="cb-tech__name">{row.name}</span>
                <span className="cb-tech__state">{stateLabel(row)}</span>
              </div>
              <div className="cb-tech__unlocks">Unlocks: {row.unlocks}</div>
              {row.requires ? <div className="cb-tech__requires">Requires: {row.requires}</div> : null}
              {row.state === "inProgress" ? (
                <div className="cb-progress" role="progressbar" aria-valuenow={row.progress ?? 0} aria-valuemax={row.cost}>
                  <div className="cb-progress__fill" style={{ width: `${Math.min(100, ((row.progress ?? 0) / row.cost) * 100)}%` }} />
                </div>
              ) : null}
            </div>
          </ListRow>
        ))}
      </InsetList>
    </Sheet>
  );
}
