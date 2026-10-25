import { Sheet } from "../Sheet/Sheet";
import { InsetList, ListRow } from "../InsetList/InsetList";
import { ownerColours, type MinimapOwner } from "../Minimap/Minimap";
import "./StandingsPanel.css";

export interface Standing {
  /** "You", or the rival town's name: "Ravenmoor". */
  name: string;
  /** Picks the dot: the player's gold or a rival's crimson, azure or emerald. */
  colour: MinimapOwner;
  /** Residents: "84". */
  population: string;
  /** The town's age: "Medieval". */
  age: string;
  /** Wealth: "$1,250". */
  wealth: string;
  /** The player's own row is bold. */
  player?: boolean;
}

export interface StandingsPanelProps {
  /** Every town, best first. */
  rows: Standing[];
  width?: number;
  height?: number;
  onDone?: () => void;
}

/**
 * The standings sheet, offered by the trophy button when the world has
 * rivals: each town's colour, name, population, age and wealth.
 */
export function StandingsPanel({ rows, width, height, onDone }: StandingsPanelProps) {
  return (
    <Sheet title="Standings" onDone={onDone} width={width} height={height}>
      <InsetList>
        {rows.map((row) => (
          <ListRow key={row.name}>
            <span className={`cb-standing ${row.player ? "cb-standing--player" : ""}`}>
              <span className="cb-standing__dot" style={{ background: ownerColours[row.colour] }} />
              <span className="cb-standing__name">{row.name}</span>
              <span className="cb-mono">{row.population}</span>
              <span className="cb-secondary">{row.age}</span>
              <span className="cb-mono">{row.wealth}</span>
            </span>
          </ListRow>
        ))}
      </InsetList>
    </Sheet>
  );
}
