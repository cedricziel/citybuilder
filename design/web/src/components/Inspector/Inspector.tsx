import { buildingSprites } from "../../generated/buildings";
import type { BuildingArt } from "../BuildingSprite/BuildingSprite";
import { Button } from "../Button/Button";
import { GoodIcon, goodName, type Good } from "../GoodIcon/GoodIcon";
import { Icon } from "../Icon/Icon";
import { MenuPicker } from "../MenuPicker/MenuPicker";
import { Parchment } from "../Parchment/Parchment";
import "./Inspector.css";

export interface InspectorNeed {
  good: Good;
  /** The house has it. A need it lacks shows as a highlighted chip tagged "short". */
  met: boolean;
}

export interface InspectorRecipe {
  /** What the producer takes in per cycle; empty for a gatherer. */
  inputs: { good: Good; amount: number }[];
  outputs: { good: Good; amount: number }[];
}

export interface InspectorProps {
  /** The building's name: "House", "Bakery". Omit for a bare list of lines. */
  title?: string;
  /** The building's sprite, drawn beside the title. */
  art?: BuildingArt;
  /** A house's tier, drawn as a dark tag: "Peasants". */
  tier?: string;
  /** A house's residents over its capacity, 0 to 1: the olive meter. */
  residentsFill?: number;
  /** A house's needs, one chip each, in the tier's order. */
  needs?: InspectorNeed[];
  /** A producer's recipe: inputs, an arrow, outputs. */
  recipe?: InspectorRecipe;
  /** What stops the building: "Output stuck: no room for bread", on a dark red band. */
  problem?: string;
  /**
   * The other key lines, in caption monospaced: "State: operational",
   * "Road: connected", "Next: Citizens need planks". The game replaces the
   * "Needs:" line with `needs` and the "Problem:" line with `problem`.
   */
  lines: string[];
  /** The gallery's commission button: its title and whether the city can afford it. */
  commission?: { title: string; enabled: boolean };
  /** The caravanserai's export picker: the options and the selected one. */
  exportPicker?: { options: string[]; selected: string };
  onCommission?: () => void;
  onPickExport?: (option: string) => void;
}

/** The inspector callout beside the selected building, on parchment. */
export function Inspector({
  title,
  art,
  tier,
  residentsFill,
  needs,
  recipe,
  problem,
  lines,
  commission,
  exportPicker,
  onCommission,
  onPickExport,
}: InspectorProps) {
  if (lines.length === 0 && !title) return null;
  return (
    <Parchment radius={10} padding="10px 12px" className="cb-inspector">
      {title ? (
        <div className="cb-inspector__head">
          {art ? <img className="cb-pixel cb-inspector__art" src={buildingSprites[art]} alt="" /> : null}
          <div className="cb-inspector__titles">
            <span className="cb-parchment-title cb-inspector__title">{title}</span>
            {tier ? <span className="cb-inspector__tier">{tier}</span> : null}
          </div>
        </div>
      ) : null}
      {residentsFill !== undefined ? (
        <div className="cb-inspector__meter" aria-label={`Residents ${Math.round(residentsFill * 100)}%`}>
          <i style={{ width: `${Math.round(residentsFill * 100)}%` }} />
        </div>
      ) : null}
      {needs && needs.length > 0 ? (
        <div className="cb-inspector__chips">
          {needs.map((need) => (
            <span
              key={need.good}
              className={`cb-inspector__chip${need.met ? "" : " cb-inspector__chip--short"}`}
              aria-label={`${goodName(need.good)}, ${need.met ? "met" : "short"}`}
            >
              <GoodIcon good={need.good} size={18} />
              {goodName(need.good)}
              {need.met ? null : " · short"}
            </span>
          ))}
        </div>
      ) : null}
      {recipe ? (
        <div className="cb-inspector__recipe">
          {recipe.inputs.map((item) => (
            <span key={item.good} className="cb-inspector__chip cb-mono">
              <GoodIcon good={item.good} size={18} />
              {item.amount}
            </span>
          ))}
          {recipe.inputs.length > 0 ? <Icon name="arrow.right" size={12} color="var(--cb-parchment-edge)" /> : null}
          {recipe.outputs.map((item) => (
            <span key={item.good} className="cb-inspector__chip cb-mono">
              <GoodIcon good={item.good} size={18} />
              {item.amount}
            </span>
          ))}
        </div>
      ) : null}
      {lines.map((line) => (
        <div key={line} className="cb-inspector__line">
          {line}
        </div>
      ))}
      {problem ? (
        <div className="cb-inspector__problem">
          <Icon name="exclamationmark.triangle.fill" size={12} />
          <span>{problem}</span>
        </div>
      ) : null}
      {commission ? (
        <Button variant="borderless" size="small" disabled={!commission.enabled} onClick={onCommission} style={{ alignSelf: "flex-start" }}>
          {commission.title}
        </Button>
      ) : null}
      {exportPicker ? (
        <MenuPicker label="Export" size="small" options={exportPicker.options} selected={exportPicker.selected} onChange={onPickExport} />
      ) : null}
    </Parchment>
  );
}
