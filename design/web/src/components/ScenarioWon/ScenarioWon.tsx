import { Icon } from "../Icon/Icon";
import { Button } from "../Button/Button";
import { Sheet } from "../Sheet/Sheet";
import "./ScenarioWon.css";

export interface ScenarioWonProps {
  /** Show "Quit to Title" under the main button. Default true. */
  canQuitToTitle?: boolean;
  width?: number;
  onKeepPlaying?: () => void;
  onQuitToTitle?: () => void;
}

/** The win sheet once every scenario goal is met: laurel, title, one line, Keep Playing. */
export function ScenarioWon({ canQuitToTitle = true, width, onKeepPlaying, onQuitToTitle }: ScenarioWonProps) {
  return (
    <Sheet doneLabel={null} background="plain" width={width}>
      <div className="cb-won">
        <Icon name="laurel.leading" size={34} />
        <div className="cb-won__title">Scenario complete</div>
        <div className="cb-won__text">Every goal is met. Keep building, or return to the title screen.</div>
        <Button variant="borderedProminent" onClick={onKeepPlaying}>
          Keep Playing
        </Button>
        {canQuitToTitle ? (
          <Button variant="borderless" onClick={onQuitToTitle}>
            Quit to Title
          </Button>
        ) : null}
      </div>
    </Sheet>
  );
}
