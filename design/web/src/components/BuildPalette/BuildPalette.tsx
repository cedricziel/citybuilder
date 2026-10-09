import { Glass } from "../Glass/Glass";
import { Icon } from "../Icon/Icon";
import "./BuildPalette.css";

export interface PaletteButtonProps {
  /** Palette name, e.g. "House", "Lumberjack", "Demolish". */
  label: string;
  /** The tool is armed: accent fill, white label. */
  armed?: boolean;
  /** Waiting on research: a lock glyph and 55% opacity (full opacity while armed). */
  locked?: boolean;
  onClick?: () => void;
}

/** One tool in the build palette: a 6px rounded monospaced caption chip with a hairline outline. */
export function PaletteButton({ label, armed, locked, onClick }: PaletteButtonProps) {
  const classes = ["cb-palette-button", armed ? "cb-palette-button--armed" : "", locked && !armed ? "cb-palette-button--locked" : ""]
    .filter(Boolean)
    .join(" ");
  return (
    <button type="button" className={classes} aria-pressed={armed} onClick={onClick}>
      {locked ? <Icon name="lock.fill" size={10} /> : null}
      <span>{label}</span>
    </button>
  );
}

export interface PaletteTool {
  /** Palette name as in `BuildTool.displayName`. */
  label: string;
  locked?: boolean;
}

export interface BuildPaletteProps {
  /** Placeable buildings in palette order. Hidden (obsolete or foreign-culture) kinds are simply left out. */
  tools: PaletteTool[];
  /** Label of the armed tool, `"Demolish"`, or omit for inspect mode (nothing armed). */
  armed?: string;
  /** Called with the tapped label. Tapping the armed tool again disarms it in the app. */
  onSelect?: (label: string) => void;
}

/**
 * The horizontal build palette under the HUD: every placeable building,
 * a divider, then Demolish. Scrolls sideways when it outgrows the screen.
 */
export function BuildPalette({ tools, armed, onSelect }: BuildPaletteProps) {
  return (
    <Glass radius={12} className="cb-palette">
      <div className="cb-palette__row">
        {tools.map((tool) => (
          <PaletteButton
            key={tool.label}
            label={tool.label}
            locked={tool.locked}
            armed={armed === tool.label}
            onClick={() => onSelect?.(tool.label)}
          />
        ))}
        <span className="cb-palette__divider" />
        <PaletteButton label="Demolish" armed={armed === "Demolish"} onClick={() => onSelect?.("Demolish")} />
      </div>
    </Glass>
  );
}

/** The app's palette order for a medieval Northern European town. */
export const defaultPaletteTools: PaletteTool[] = [
  { label: "House" },
  { label: "Warehouse" },
  { label: "Road" },
  { label: "Lumberjack" },
  { label: "Sawmill" },
  { label: "Farm" },
  { label: "Grain Farm" },
  { label: "Windmill" },
  { label: "Bakery" },
  { label: "Mine" },
  { label: "Charcoal" },
  { label: "Smelter" },
  { label: "Toolsmith", locked: true },
  { label: "Library" },
  { label: "Hop Garden" },
  { label: "Brewery", locked: true },
  { label: "Port" },
  { label: "Shipyard", locked: true },
  { label: "Guild Hall", locked: true },
  { label: "Mead Hall" },
];
