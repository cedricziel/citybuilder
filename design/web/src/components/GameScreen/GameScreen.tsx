import type { ReactNode } from "react";
import { WorldBackdrop, type PlacedBuilding, type WorldBackdropProps } from "../WorldBackdrop/WorldBackdrop";
import { HUDFrame, type HUDFrameProps } from "../HUDFrame/HUDFrame";
import { HUDButtonCluster } from "../HUDButton/HUDButton";
import { BuildPalette, defaultPaletteTools, type PaletteTool } from "../BuildPalette/BuildPalette";
import { CostBreakdown, type CostLine } from "../CostBreakdown/CostBreakdown";
import { HintCapsule } from "../HintCapsule/HintCapsule";
import { RejectionBanner } from "../RejectionBanner/RejectionBanner";
import { SessionBanner } from "../SessionBanner/SessionBanner";
import { Inspector, type InspectorProps } from "../Inspector/Inspector";
import { Coachmark } from "../Coachmark/Coachmark";
import { PlacementHUD } from "../PlacementHUD/PlacementHUD";
import { Button } from "../Button/Button";
import "./GameScreen.css";

export interface GameScreenProps {
  /** Screen size in px. Default 844x390 (iPhone landscape). iPad: 1180x820, Mac window: 1280x800. */
  width?: number;
  height?: number;
  /** `touch` (iPhone/iPad: Actions button, coachmark, placement HUD) or `mac`. Default `touch`. */
  device?: "touch" | "mac";
  /** HUD panel content. Default: a medieval town in spring. */
  hud?: HUDFrameProps;
  /** Palette tools. Default `defaultPaletteTools`. */
  tools?: PaletteTool[];
  /** Armed tool label (`"Demolish"` for demolish); omit for inspect mode. */
  armed?: string;
  /** Caption under the palette while a tool is armed, e.g. "Tap or drag to place house — $120". */
  armedCaption?: string;
  /** Materials for the armed building (`CostBreakdown`). */
  cost?: CostLine[];
  /** The red rejection capsule. */
  rejection?: string;
  /** The parchment announcement. */
  banner?: { title: string; description: string };
  /** Inspector content (inspect mode only). */
  inspector?: InspectorProps;
  /** Show the iOS first-run "Long-press a tile to build" hint. */
  coachmark?: boolean;
  /** A pending touch placement: the ghost building and whether it is valid, drawn mid-screen with the nudge HUD. */
  placing?: { art: PlacedBuilding["art"]; valid?: boolean };
  /** Map props passed to `WorldBackdrop` (map, buildings, zoom, season, selected). */
  world?: Omit<WorldBackdropProps, "width" | "height" | "children">;
  /** A sheet presented over the game (GoalsPanel, ResearchPanel, PauseMenu ...). */
  sheet?: ReactNode;
  /** Any extra overlay. */
  children?: ReactNode;
}

const defaultHud: HUDFrameProps = {
  date: "Spring 1203",
  timeOfDay: "day",
  money: "$1,250",
  population: "Pop. 84",
  island: "Greenhold",
  stocks: [
    { good: "wood", count: 42 },
    { good: "planks", count: 18 },
    { good: "food", count: 31 },
    { good: "grain", count: 12 },
    { good: "flour", count: 6 },
    { good: "bread", count: 9 },
  ],
};

/**
 * A whole in-game screen: the world map with the HUD stacked down the left
 * (HUD panel and button cluster, palette, banners, armed caption), the
 * inspector at the bottom, and optional touch overlays or a sheet. Start
 * here for any gameplay mock.
 */
export function GameScreen({
  width = 844,
  height = 390,
  device = "touch",
  hud = defaultHud,
  tools = defaultPaletteTools,
  armed,
  armedCaption,
  cost,
  rejection,
  banner,
  inspector,
  coachmark,
  placing,
  world,
  sheet,
  children,
}: GameScreenProps) {
  const touch = device === "touch";
  return (
    <WorldBackdrop width={width} height={height} {...world}>
      <div className="cb-game">
        <div className="cb-game__top">
          <HUDFrame {...hud} />
          <HUDButtonCluster />
        </div>
        <BuildPalette tools={tools} armed={armed} />
        {rejection ? <RejectionBanner message={rejection} /> : null}
        {banner ? <SessionBanner title={banner.title} description={banner.description} /> : null}
        {armed && armedCaption ? <HintCapsule>{armedCaption}</HintCapsule> : null}
        {armed && cost && cost.length > 0 ? <CostBreakdown lines={cost} /> : null}
        <div className="cb-game__spacer" />
        {!armed && inspector && inspector.lines.length > 0 ? (
          <div className="cb-game__bottom">
            <Inspector {...inspector} />
            {touch ? (
              <Button variant="bordered" icon="ellipsis.circle" style={{ background: "var(--cb-material)" }}>
                Actions
              </Button>
            ) : null}
          </div>
        ) : null}
      </div>
      {touch && placing ? (
        <div className="cb-game__placing">
          <PlacementHUD valid={placing.valid ?? true} building={placing.art} />
        </div>
      ) : null}
      {touch && coachmark && !placing ? (
        <div className="cb-game__coachmark">
          <Coachmark />
        </div>
      ) : null}
      {children}
      {sheet ? (
        <div className={`cb-game__scrim ${height > 600 ? "cb-game__scrim--centered" : ""}`}>
          <div className="cb-game__sheet">{sheet}</div>
        </div>
      ) : null}
    </WorldBackdrop>
  );
}
