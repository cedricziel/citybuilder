import { Sheet } from "../Sheet/Sheet";
import { InsetList, ListRow } from "../InsetList/InsetList";
import { Icon } from "../Icon/Icon";
import "./GoalsPanel.css";

export interface GoalRow {
  /** "Residents 32/40", "Bread 20/20", "Reach the Industrial age". */
  text: string;
  met: boolean;
}

export interface GoalsDeadline {
  /** The limit itself, e.g. "Before 1210". */
  label: string;
  /** Time to the limit, e.g. "1 year, 2 seasons left". */
  remaining: string;
}

export interface GoalsRace {
  /** What the race is for, e.g. "First to the Renaissance". */
  title: string;
  /** The player's progress, e.g. "42/60". */
  player: string;
  /** The leading rival's town, e.g. "Ravenshore". */
  rival: string;
  /** The leading rival's progress, e.g. "50/60". */
  rivalProgress: string;
  /** The rival is ahead: their figure turns orange. */
  rivalAhead?: boolean;
}

export interface GoalsPanelProps {
  goals: GoalRow[];
  /** A chapter's bonus goals, listed under "Bonus · one laurel each". */
  bonus?: GoalRow[];
  /** A chapter's deadline, as a row under the goals. */
  deadline?: GoalsDeadline;
  /** A chapter's rival race: the player's progress next to the leading rival's. */
  race?: GoalsRace;
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
            <Icon
              name={goal.met ? "checkmark.circle.fill" : "circle"}
              size={20}
            />
            {goal.text}
          </span>
        </ListRow>
      ))}
    </>
  );
}

/**
 * The goals sheet: one row per goal, green with a filled check once met.
 * In a campaign chapter it adds the deadline, the rival race and the bonus goals.
 */
export function GoalsPanel({
  goals,
  bonus,
  deadline,
  race,
  width,
  height,
  onDone,
}: GoalsPanelProps) {
  return (
    <Sheet title="Goals" onDone={onDone} width={width} height={height}>
      <InsetList>
        <GoalRows goals={goals} />
        {deadline ? (
          <ListRow>
            <span className="cb-goal-pair">
              <span>{deadline.label}</span>
              <span className="cb-goal-pair__value">{deadline.remaining}</span>
            </span>
          </ListRow>
        ) : null}
      </InsetList>
      {race ? (
        <InsetList header={race.title}>
          <ListRow>
            <span className="cb-goal-pair">
              <span>
                You <span className="cb-mono">{race.player}</span>
              </span>
              <span
                className={`cb-goal-pair__value${race.rivalAhead ? " cb-goal-pair__value--ahead" : ""}`}
              >
                {race.rival}{" "}
                <span className="cb-mono">{race.rivalProgress}</span>
              </span>
            </span>
          </ListRow>
        </InsetList>
      ) : null}
      {bonus && bonus.length > 0 ? (
        <InsetList header="Bonus · one laurel each">
          <GoalRows goals={bonus} />
        </InsetList>
      ) : null}
    </Sheet>
  );
}
