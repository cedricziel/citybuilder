import { buildingSprites } from "../../generated/buildings";
import type { BuildingArt } from "../BuildingSprite/BuildingSprite";
import { Glass } from "../Glass/Glass";
import { Icon } from "../Icon/Icon";
import "./BuildDrawer.css";

export interface DrawerTile {
  /** Palette name as in `BuildingKind.displayName`: "House", "Lumberjack", "Grain Farm". */
  label: string;
  /** The building's sprite, drawn as its icon. */
  art: BuildingArt;
  /** Price in dollars, the caption of an unlocked tile: "$120". */
  cost: number;
  /**
   * The tech the building waits on. Set, the tile is locked: a lock glyph,
   * half opacity, disabled, and the caption reads "Needs Mining" instead of the price.
   */
  needs?: string;
}

export interface BuildDrawerProps {
  /** The open category: "Town", "Gather" or "Craft". */
  category: string;
  /** The category's buildings, in palette order. */
  tiles: DrawerTile[];
  /** Label of the armed tile: an accent outline. */
  armed?: string;
  /** Grid columns: 3 on iPad and Mac, 4 on iPhone and in the portrait dock. Default 3. */
  columns?: 3 | 4;
  /** Tile width: 92 on iPad and Mac, 78 on iPhone. Default 92. */
  tileWidth?: 78 | 92;
  onSelect?: (label: string) => void;
  onClose?: () => void;
}

/** A drawer tile's caption: its price, or the tech it waits on. */
export function drawerCaption(tile: DrawerTile): string {
  return tile.needs ? `Needs ${tile.needs}` : `$${tile.cost.toLocaleString("en-US")}`;
}

/**
 * The open build category's drawer next to the build rail: a glass panel with
 * the category's name and a grid of tiles, each with the building's sprite,
 * its name and its price, or the tech that unlocks it.
 */
export function BuildDrawer({ category, tiles, armed, columns = 3, tileWidth = 92, onSelect, onClose }: BuildDrawerProps) {
  return (
    <Glass radius={12} padding={10} className="cb-drawer">
      <div className="cb-drawer__header">
        <span className="cb-headline">{category}</span>
        <button type="button" className="cb-drawer__close" aria-label="Close" onClick={onClose}>
          <Icon name="xmark" size={12} />
        </button>
      </div>
      <div className="cb-drawer__grid" style={{ gridTemplateColumns: `repeat(${columns}, ${tileWidth}px)` }}>
        {tiles.map((tile) => {
          const locked = Boolean(tile.needs);
          const classes = ["cb-drawer__tile", armed === tile.label ? "cb-drawer__tile--armed" : "", locked ? "cb-drawer__tile--locked" : ""]
            .filter(Boolean)
            .join(" ");
          return (
            <button
              type="button"
              key={tile.label}
              className={classes}
              disabled={locked}
              aria-label={locked ? `${tile.label}, locked` : tile.label}
              onClick={() => onSelect?.(tile.label)}
            >
              <span className="cb-drawer__art">
                <img src={buildingSprites[tile.art]} alt="" />
              </span>
              <span className="cb-drawer__name">
                {locked ? <Icon name="lock.fill" size={9} /> : null}
                <span>{tile.label}</span>
              </span>
              <span className="cb-drawer__caption">{drawerCaption(tile)}</span>
            </button>
          );
        })}
      </div>
    </Glass>
  );
}

/** The Gather drawer of a young medieval town: Mining and Cultivation not yet researched. */
export const gatherDrawerTiles: DrawerTile[] = [
  { label: "Lumberjack", art: "lumberjack-hut", cost: 80 },
  { label: "Forester", art: "forester", cost: 60 },
  { label: "Farm", art: "farm", cost: 60 },
  { label: "Grain Farm", art: "grain-farm", cost: 60 },
  { label: "Sheep Farm", art: "sheep-farm", cost: 60, needs: "Weaving" },
  { label: "Mine", art: "mine", cost: 120, needs: "Mining" },
  { label: "Hop Garden", art: "hop-garden", cost: 60, needs: "Cultivation" },
];
