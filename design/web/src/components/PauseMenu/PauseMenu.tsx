import { Icon, type IconName } from "../Icon/Icon";
import { Sheet } from "../Sheet/Sheet";
import "./PauseMenu.css";

export interface PauseAction {
  label: string;
  icon: IconName;
  destructive?: boolean;
}

export interface PauseMenuProps {
  /** Rows in order. Default: Resume, Save Game, Settings, Quit to Title. Add Quit (`power`, destructive) on the Mac. */
  actions?: PauseAction[];
  /** Transient feedback under the rows, e.g. "Saved." (cleared after 2 s in the app). */
  status?: string;
  width?: number;
  onAction?: (label: string) => void;
}

export const defaultPauseActions: PauseAction[] = [
  { label: "Resume", icon: "play.fill" },
  { label: "Save Game", icon: "tray.and.arrow.down" },
  { label: "Settings", icon: "gear" },
  { label: "Quit to Title", icon: "house" },
];

/** The modal pause sheet: "Game Paused" over full-width tinted action rows. */
export function PauseMenu({ actions = defaultPauseActions, status, width, onAction }: PauseMenuProps) {
  return (
    <Sheet doneLabel={null} background="plain" width={width} style={{ minHeight: 320 }}>
      <div className="cb-pause">
        <div className="cb-pause__title">Game Paused</div>
        <div className="cb-pause__actions">
          {actions.map((action) => (
            <button
              key={action.label}
              type="button"
              className={`cb-pause__row ${action.destructive ? "cb-pause__row--destructive" : ""}`}
              onClick={() => onAction?.(action.label)}
            >
              <span className="cb-pause__icon">
                <Icon name={action.icon} size={17} />
              </span>
              {action.label}
            </button>
          ))}
        </div>
        {status ? <div className="cb-pause__status">{status}</div> : null}
      </div>
    </Sheet>
  );
}
