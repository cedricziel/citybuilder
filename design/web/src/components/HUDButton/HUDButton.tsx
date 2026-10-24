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

export interface HUDMenuButtonsProps {
  /** Scenario goals (only scenarios have goals). Default true. */
  goals?: boolean;
  /** The standings trophy (only worlds with rivals). Default false. */
  standings?: boolean;
  /** Trade routes (once the town has a ship). Default false. */
  routes?: boolean;
  /** The minimap toggle; `shown` fills the map symbol. Default `shown`; `none` hides it (Apple TV). */
  minimap?: "shown" | "hidden" | "none";
  /** Settings (when the app wires a settings view). Default true. */
  settings?: boolean;
  /** A phone in portrait folds every button into one More menu button. Default false. */
  folded?: boolean;
  onSelect?: (button: "goals" | "research" | "standings" | "routes" | "minimap" | "settings" | "more") => void;
}

/**
 * The HUD's menu buttons in one row at the top right, right of the status
 * pill: goals, research, standings, routes, the minimap toggle and settings.
 * Pause lives in the status pill. A phone in portrait folds them into More.
 */
export function HUDMenuButtons({
  goals = true,
  standings = false,
  routes = false,
  minimap = "shown",
  settings = true,
  folded = false,
  onSelect,
}: HUDMenuButtonsProps) {
  if (folded) {
    return (
      <div className="cb-hud-cluster__row">
        <HUDButton icon="ellipsis.circle" label="More" onClick={() => onSelect?.("more")} />
      </div>
    );
  }
  return (
    <div className="cb-hud-cluster__row">
      {goals ? <HUDButton icon="flag.checkered" label="Goals" onClick={() => onSelect?.("goals")} /> : null}
      <HUDButton icon="book.fill" label="Research" onClick={() => onSelect?.("research")} />
      {standings ? <HUDButton icon="trophy.fill" label="Standings" onClick={() => onSelect?.("standings")} /> : null}
      {routes ? <HUDButton icon="ferry.fill" label="Routes" onClick={() => onSelect?.("routes")} /> : null}
      {minimap !== "none" ? (
        <HUDButton
          icon={minimap === "shown" ? "map.fill" : "map"}
          label={minimap === "shown" ? "Hide Minimap" : "Show Minimap"}
          onClick={() => onSelect?.("minimap")}
        />
      ) : null}
      {settings ? <HUDButton icon="gearshape.fill" label="Settings" onClick={() => onSelect?.("settings")} /> : null}
    </div>
  );
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
