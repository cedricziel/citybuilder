import { Glass } from "../Glass/Glass";
import { Icon, type IconName } from "../Icon/Icon";
import "./HUDButton.css";

export interface HUDButtonProps {
  /** SF Symbol: `pause.fill`, `gearshape.fill`, `book.fill` (research), `flag.checkered` (goals). */
  icon: IconName;
  /** Accessible label: "Pause", "Settings", "Research", "Goals". */
  label: string;
  onClick?: () => void;
}

/** A round thin-material icon button from the HUD's top-right cluster. */
export function HUDButton({ icon, label, onClick }: HUDButtonProps) {
  return (
    <button type="button" className="cb-hud-button" aria-label={label} title={label} onClick={onClick}>
      <Glass shape="circle" className="cb-hud-button__disc">
        <Icon name={icon} size={20} />
      </Glass>
    </button>
  );
}

export interface HUDButtonClusterProps {
  /** Show the settings button (the app hides it when no settings view is wired). Default true. */
  showSettings?: boolean;
  /** Show the goals flag (only scenarios have goals). Default true. */
  showGoals?: boolean;
  onPause?: () => void;
  onSettings?: () => void;
  onResearch?: () => void;
  onGoals?: () => void;
}

/** The HUD's 2x2 button cluster: pause and settings over research and goals. */
export function HUDButtonCluster({
  showSettings = true,
  showGoals = true,
  onPause,
  onSettings,
  onResearch,
  onGoals,
}: HUDButtonClusterProps) {
  return (
    <div className="cb-hud-cluster">
      <div className="cb-hud-cluster__row">
        <HUDButton icon="pause.fill" label="Pause" onClick={onPause} />
        {showSettings ? <HUDButton icon="gearshape.fill" label="Settings" onClick={onSettings} /> : null}
      </div>
      <div className="cb-hud-cluster__row">
        <HUDButton icon="book.fill" label="Research" onClick={onResearch} />
        {showGoals ? <HUDButton icon="flag.checkered" label="Goals" onClick={onGoals} /> : null}
      </div>
    </div>
  );
}
