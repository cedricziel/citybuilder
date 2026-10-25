import { Icon } from "../Icon/Icon";
import "./StatusPill.css";

export type GameSpeed = 1 | 2 | 3;

export interface StatusPillProps {
  /** Season and year, "Spring 1203". Hidden on a phone (its `DateChip` shows it) and when empty. */
  date?: string;
  /** Picks the symbol next to the date. Default `day`. */
  timeOfDay?: "dawn" | "day" | "dusk" | "night";
  /** Formatted balance: "$1,250", "-$40". */
  money: string;
  /** Residents, "84". */
  population: string;
  /** The island under the camera; its button opens the stocks tray. */
  island?: string;
  /** The stocks tray is open: the chevron points up. */
  stocksOpen?: boolean;
  /** Paused: the pause button fills with the accent and shows play. */
  paused?: boolean;
  /** The running speed. Default 1. */
  speed?: GameSpeed;
  /**
   * `pad` (50pt tall, the default), `mac` (40pt) or `phone` (50pt, no date,
   * one cycling speed button instead of three segments).
   */
  device?: "pad" | "mac" | "phone";
  onTogglePause?: () => void;
  onSpeed?: (speed: GameSpeed) => void;
  onToggleStocks?: () => void;
}

const symbols = { dawn: "sunrise.fill", day: "sun.max.fill", dusk: "sunset.fill", night: "moon.stars.fill" } as const;

/**
 * Date, money, population, island and game speed in one thin-material
 * capsule at the top of the game screen. The island opens the stocks tray.
 */
export function StatusPill({
  date,
  timeOfDay = "day",
  money,
  population,
  island,
  stocksOpen = false,
  paused = false,
  speed = 1,
  device = "pad",
  onTogglePause,
  onSpeed,
  onToggleStocks,
}: StatusPillProps) {
  const phone = device === "phone";
  return (
    <div className={`cb-status-pill cb-status-pill--${device}`}>
      {!phone && date ? (
        <span className="cb-status-pill__date">
          <Icon name={symbols[timeOfDay]} size={14} />
          <span>{date}</span>
        </span>
      ) : null}
      <Stat label="Money" value={money} mono />
      <Stat label="Pop." value={population} mono />
      {island ? (
        <button type="button" className="cb-status-pill__island" aria-expanded={stocksOpen} onClick={onToggleStocks}>
          <Stat label="Island" value={island} />
          <span className={`cb-status-pill__chevron ${stocksOpen ? "cb-status-pill__chevron--open" : ""}`}>
            <Icon name="chevron.down" size={11} />
          </span>
        </button>
      ) : null}
      <SpeedControl paused={paused} speed={speed} cycle={phone} onTogglePause={onTogglePause} onSpeed={onSpeed} />
    </div>
  );
}

function Stat({ label, value, mono }: { label: string; value: string; mono?: boolean }) {
  return (
    <span className="cb-status-pill__stat">
      <span className="cb-status-pill__caption">{label}</span>
      <span className={`cb-status-pill__value ${mono ? "cb-mono" : ""}`}>{value}</span>
    </span>
  );
}

export interface SpeedControlProps {
  paused?: boolean;
  speed?: GameSpeed;
  /** One button that steps 1×, 2×, 3× (the phone). Default false: three segments. */
  cycle?: boolean;
  onTogglePause?: () => void;
  onSpeed?: (speed: GameSpeed) => void;
}

/** Pause plus 1×, 2× and 3× in a nested capsule; choosing a speed resumes. */
export function SpeedControl({ paused = false, speed = 1, cycle = false, onTogglePause, onSpeed }: SpeedControlProps) {
  const speeds: GameSpeed[] = [1, 2, 3];
  return (
    <span className="cb-speed">
      <button
        type="button"
        className={`cb-speed__pause ${paused ? "cb-speed__pause--on" : ""}`}
        aria-label={paused ? "Resume" : "Pause"}
        onClick={onTogglePause}
      >
        <Icon name={paused ? "play.fill" : "pause.fill"} size={15} />
      </button>
      {cycle ? (
        <button type="button" className="cb-speed__segment cb-speed__segment--cycle" onClick={() => onSpeed?.(((speed % 3) + 1) as GameSpeed)}>
          {speed}×
        </button>
      ) : (
        speeds.map((option) => (
          <button
            type="button"
            key={option}
            className={`cb-speed__segment ${!paused && speed === option ? "cb-speed__segment--on" : ""}`}
            aria-pressed={!paused && speed === option}
            onClick={() => onSpeed?.(option)}
          >
            {option}×
          </button>
        ))
      )}
    </span>
  );
}
