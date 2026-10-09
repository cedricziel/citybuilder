import type { ReactNode } from "react";
import { Icon, type IconName } from "../Icon/Icon";
import { BuildingSprite, type BuildingArt } from "../BuildingSprite/BuildingSprite";
import "./PlacementHUD.css";

export type NudgeDirection = "ne" | "se" | "sw" | "nw";

export interface PlacementHUDProps {
  /** Whether confirming would place the building now: green check when valid, orange when not. Default true. */
  valid?: boolean;
  /** Directions whose nudge would leave the map; drawn disabled. */
  disabled?: NudgeDirection[];
  /** The ghost building drawn on the pending tile. Omit to draw only the tile diamond. */
  building?: BuildingArt;
  /** Replaces the ghost, e.g. a world fragment. */
  children?: ReactNode;
  onNudge?: (direction: NudgeDirection) => void;
  onConfirm?: () => void;
  onCancel?: () => void;
}

const arrows: { direction: NudgeDirection; icon: IconName; x: number; y: number }[] = [
  { direction: "ne", icon: "arrow.up.right", x: 75, y: -38 },
  { direction: "se", icon: "arrow.down.right", x: 75, y: 38 },
  { direction: "sw", icon: "arrow.down.left", x: -75, y: 38 },
  { direction: "nw", icon: "arrow.up.left", x: -75, y: -38 },
];

const center = { x: 130, y: 104 };
const below = center.y + 84 + 32;

/**
 * The iOS touch-placement HUD around a pending building: four 44px glass
 * arrows along the iso diagonals (84px out), then cancel (red) and confirm
 * (green, orange when invalid) side by side under the ghost.
 */
export function PlacementHUD({ valid = true, disabled = [], building, children, onNudge, onConfirm, onCancel }: PlacementHUDProps) {
  return (
    <div className="cb-placement">
      <div className="cb-placement__ghost" style={{ left: center.x, top: center.y }}>
        {children ?? (
          <>
            <div className={`cb-placement__tile ${valid ? "" : "cb-placement__tile--invalid"}`} />
            {building ? <BuildingSprite building={building} style={{ position: "absolute", left: -64, bottom: -16, opacity: 0.75 }} /> : null}
          </>
        )}
      </div>
      {arrows.map((arrow) => (
        <HUDCircle
          key={arrow.direction}
          icon={arrow.icon}
          label={`Move ${arrow.direction}`}
          tint="var(--cb-accent)"
          x={center.x + arrow.x}
          y={center.y + arrow.y}
          disabled={disabled.includes(arrow.direction)}
          onClick={() => onNudge?.(arrow.direction)}
        />
      ))}
      <HUDCircle icon="xmark" label="Cancel" tint="var(--cb-red)" x={center.x - 32} y={below} onClick={onCancel} />
      <HUDCircle icon="checkmark" label="Place" tint={valid ? "var(--cb-green)" : "var(--cb-orange)"} x={center.x + 32} y={below} onClick={onConfirm} />
    </div>
  );
}

function HUDCircle(props: { icon: IconName; label: string; tint: string; x: number; y: number; disabled?: boolean; onClick?: () => void }) {
  return (
    <button
      type="button"
      className="cb-placement__button"
      aria-label={props.label}
      disabled={props.disabled}
      onClick={props.onClick}
      style={{ left: props.x - 22, top: props.y - 22, color: props.tint, borderColor: props.tint }}
    >
      <Icon name={props.icon} size={20} />
    </button>
  );
}
