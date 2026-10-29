import { Sheet } from "../Sheet/Sheet";
import { InsetList, ListRow } from "../InsetList/InsetList";
import { Icon } from "../Icon/Icon";
import "./GoalsPanel.css";

export interface GoalRow {
  /** "Residents 32/40", "Bread 20/20", "Reach the Industrial age". */
  text: string;
  met: boolean;
}

export interface GoalsRace {
  /** What the race is for, e.g. "First to the Renaissance". */
  title: string;
  /** The player's standing, e.g. "You 42/60" or "You: Medieval". */
  player: string;
  /** The leading rival's standing, e.g. "Ravenshore 50/60". */
  rival: string;
}

export interface GoalsPanelProps {
  goals: GoalRow[];
  /** A chapter's bonus goals, listed under "Bonus · one laurel each". */
  bonus?: GoalRow[];
  /** A chapter's rival race: the player's standing beside the leading rival's. */
  race?: GoalsRace;
  /** Time to a chapter's deadline, e.g. "1 year, 2 seasons left". The last row, with an hourglass. */
  deadline?: string;
  width?: number;
  height?: number;
  onDone?: () => void;
}

function GoalRows({ goals }: { goals: GoalRow[] }) {
  return (
    <>
      {goals.map((goal) => (
        <ListRow key={goal.text}>
          <span className={`cb-goal ${goal.met ? "cb-goal--met" : ""}`}>
            <Icon name={goal.met ? "checkmark.circle.fill" : "circle"} size={20} />
            {goal.text}
          </span>
        </ListRow>
      ))}
    </>
  );
}

/**
 * The goals sheet: one row per goal, green with a filled check once met.
 * In a campaign chapter it adds the bonus goals, the rival race and, last,
 * the time left before the deadline.
 */
export function GoalsPanel({ goals, bonus, race, deadline, width, height, onDone }: GoalsPanelProps) {
  return (
    <Sheet title="Goals" onDone={onDone} width={width} height={height}>
      <InsetList>
        <GoalRows goals={goals} />
      </InsetList>
      {bonus && bonus.length > 0 ? (
        <InsetList header="Bonus · one laurel each">
          <GoalRows goals={bonus} />
        </InsetList>
      ) : null}
      {race ? (
        <InsetList header={race.title}>
          <ListRow>
            <span className="cb-goal-pair">
              <span>{race.player}</span>
              <span className="cb-goal-pair__value">{race.rival}</span>
            </span>
          </ListRow>
        </InsetList>
      ) : null}
      {deadline ? (
        <InsetList>
          <ListRow>
            <span className="cb-goal cb-goal--deadline">
              <Icon name="hourglass" size={20} />
              {deadline}
            </span>
          </ListRow>
        </InsetList>
      ) : null}
    </Sheet>
  );
}
