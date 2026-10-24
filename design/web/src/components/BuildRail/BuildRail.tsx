import { buildingSprites } from "../../generated/buildings";
import type { BuildingArt } from "../BuildingSprite/BuildingSprite";
import { Glass } from "../Glass/Glass";
import { Icon } from "../Icon/Icon";
import "./BuildRail.css";

export type BuildRailItem = "Town" | "Gather" | "Craft" | "Road" | "Demolish";

export interface BuildRailProps {
  /**
   * `rail`: a column on the left edge (landscape). `dock`: a row along the
   * bottom (portrait). Default `rail`.
   */
  placement?: "rail" | "dock";
  /** The highlighted item: the open drawer's category, or the armed Road or Demolish. */
  active?: BuildRailItem;
  /** Phone sizes: a 56pt rail without labels, 64pt dock items. Default false. */
  phone?: boolean;
  /** Show the Mac hotkey letters (1, 2, 3, R, X) in each item's corner. Default false. */
  hotkeys?: boolean;
  onSelect?: (item: BuildRailItem) => void;
}

const items: { label: BuildRailItem; art?: BuildingArt; hotkey: string }[] = [
  { label: "Town", art: "house", hotkey: "1" },
  { label: "Gather", art: "lumberjack-hut", hotkey: "2" },
  { label: "Craft", art: "sawmill", hotkey: "3" },
  { label: "Road", art: "road", hotkey: "R" },
  { label: "Demolish", hotkey: "X" },
];

/**
 * Town, Gather and Craft, then Road and Demolish: the build controls on a
 * 12pt glass rail at the left edge in landscape, or a dock along the bottom
 * in portrait. A category opens its `BuildDrawer`.
 */
export function BuildRail({ placement = "rail", active, phone = false, hotkeys = false, onSelect }: BuildRailProps) {
  const vertical = placement === "rail";
  const labels = !vertical || !phone;
  const classes = ["cb-rail", `cb-rail--${placement}`, phone ? "cb-rail--phone" : "", labels ? "" : "cb-rail--no-labels"]
    .filter(Boolean)
    .join(" ");
  return (
    <Glass radius={12} padding={4} className={classes}>
      {items.map((item, index) => (
        <span key={item.label} className="cb-rail__slot">
          {index === 3 ? <span className="cb-rail__separator" /> : null}
          <button
            type="button"
            className={`cb-rail__item ${active === item.label ? "cb-rail__item--on" : ""}`}
            aria-label={item.label}
            aria-pressed={active === item.label}
            onClick={() => onSelect?.(item.label)}
          >
            <span className="cb-rail__art">
              {item.art ? <img src={buildingSprites[item.art]} alt="" /> : <Icon name="xmark" size={20} color="var(--cb-red)" />}
            </span>
            {labels ? <span className="cb-rail__label">{item.label}</span> : null}
            {hotkeys ? <span className="cb-rail__hotkey">{item.hotkey}</span> : null}
          </button>
        </span>
      ))}
    </Glass>
  );
}
