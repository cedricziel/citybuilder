import { buildingSprites } from "../../generated/buildings";
import type { BuildingArt } from "../BuildingSprite/BuildingSprite";
import type { CostLine } from "../CostBreakdown/CostBreakdown";
import { Glass } from "../Glass/Glass";
import { GoodChip } from "../GoodChip/GoodChip";
import { Icon } from "../Icon/Icon";
import "./ToolStrip.css";

export interface ToolStripProps {
  /** The armed tool's name: "House", "Lumberjack", "Demolish". */
  tool: string;
  /** The armed building's sprite; omit for Demolish (a red cross). */
  art?: BuildingArt;
  /** Price in dollars; omitted or 0 shows none. */
  cost?: number;
  /**
   * The hint: "Click or drag to place house" on the Mac, "Tap to position, then tap ✓ to place" for a
   * building on touch ("Tap or drag to place road" for a road), with " · 18 trees in reach" for a
   * lumberjack and the first-hour guide's warning (" · No farm yet: residents need food").
   */
  hint: string;
  /** The materials the building takes, as have/need chips after a divider. */
  materials?: CostLine[];
  onCancel?: () => void;
}

/**
 * The armed tool along the bottom of the screen: its sprite, name and
 * price, what to do, the materials it takes and a cancel cross, on a 12pt
 * glass strip. The rejection banner sits right above it.
 */
export function ToolStrip({ tool, art, cost, hint, materials = [], onCancel }: ToolStripProps) {
  return (
    <Glass radius={12} padding="6px 6px 6px 10px" className="cb-tool-strip">
      <span className="cb-tool-strip__art">
        {art ? <img src={buildingSprites[art]} alt="" /> : <Icon name="xmark" size={16} color="var(--cb-red)" />}
      </span>
      <span className="cb-tool-strip__text">
        <span className="cb-tool-strip__title">
          {tool}
          {cost ? <span className="cb-tool-strip__cost"> · ${cost.toLocaleString("en-US")}</span> : null}
        </span>
        <span className="cb-tool-strip__hint">{hint}</span>
      </span>
      {materials.length > 0 ? (
        <>
          <span className="cb-tool-strip__divider" />
          {materials.map((line) => (
            <GoodChip
              key={line.good}
              good={line.good}
              have={line.have}
              need={line.need}
              status={line.status ?? (line.have >= line.need ? "ok" : "blocked")}
            />
          ))}
        </>
      ) : null}
      <button type="button" className="cb-tool-strip__cancel" aria-label="Cancel tool" onClick={onCancel}>
        <Icon name="xmark" size={13} />
      </button>
    </Glass>
  );
}
