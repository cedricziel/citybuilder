import { Sheet } from "../Sheet/Sheet";
import { InsetList, ListRow } from "../InsetList/InsetList";
import { Icon } from "../Icon/Icon";
import "./GoalsPanel.css";

export interface GoalRow {
  /** "Residents 32/40", "Bread 20/20", "Reach the Industrial age". */
  text: string;
  met: boolean;
}

export interface GoalsPanelProps {
  goals: GoalRow[];
  width?: number;
  height?: number;
  onDone?: () => void;
}

/** The scenario goals sheet: one row per goal, green with a filled check once met. */
export function GoalsPanel({ goals, width, height, onDone }: GoalsPanelProps) {
  return (
    <Sheet title="Goals" onDone={onDone} width={width} height={height}>
      <InsetList>
        {goals.map((goal) => (
          <ListRow key={goal.text}>
            <span className={`cb-goal ${goal.met ? "cb-goal--met" : ""}`}>
              <Icon name={goal.met ? "checkmark.circle.fill" : "circle"} size={20} />
              {goal.text}
            </span>
          </ListRow>
        ))}
      </InsetList>
    </Sheet>
  );
}
