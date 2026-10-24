import type { ReactNode } from "react";
import { WorldBackdrop, defaultTown, type AreaOfEffect, type PlacedBuilding, type WorldBackdropProps } from "../WorldBackdrop/WorldBackdrop";
import type { HUDFrameProps } from "../HUDFrame/HUDFrame";
import { HUDMenuButtons, type HUDMenuButtonsProps } from "../HUDButton/HUDButton";
import { StatusPill, type GameSpeed } from "../StatusPill/StatusPill";
import { StocksTray } from "../StocksTray/StocksTray";
import { BuildRail, type BuildRailItem } from "../BuildRail/BuildRail";
import { BuildDrawer, type BuildDrawerProps } from "../BuildDrawer/BuildDrawer";
import { ToolStrip, type ToolStripProps } from "../ToolStrip/ToolStrip";
import { Minimap, type MinimapBuilding } from "../Minimap/Minimap";
import { RejectionBanner } from "../RejectionBanner/RejectionBanner";
import { SessionBanner } from "../SessionBanner/SessionBanner";
import { Inspector, type InspectorProps } from "../Inspector/Inspector";
import { Coachmark } from "../Coachmark/Coachmark";
import { PlacementHUD } from "../PlacementHUD/PlacementHUD";
import { Button } from "../Button/Button";
import { FirstStepsCard, type FirstStepsCardProps } from "../FirstStepsCard/FirstStepsCard";
import { AreaCountCapsule, type AreaCountTone } from "../AreaCountCapsule/AreaCountCapsule";
import "./GameScreen.css";

export interface GameScreenProps {
  /** Screen size in px. Default 1180x820 (iPad landscape). iPhone landscape 844x390, iPad portrait 820x1180, Mac 1280x800. */
  width?: number;
  height?: number;
  /**
   * `pad` (the default), `phone` or `mac`. Touch devices add the Actions
   * button, coachmark and placement HUD; the phone narrows the rail and
   * hides the minimap; the Mac shows hotkeys. `touch` is an alias of `pad`.
   */
  device?: "pad" | "phone" | "mac" | "touch";
  /**
   * `rail` (build controls on the left edge) or `dock` (along the bottom).
   * Default: `rail` when the screen is wider than tall, as in the game.
   */
  placement?: "rail" | "dock";
  /** The status pill's date, money, population and island, and the stocks tray's goods. Default: a medieval town in spring. */
  hud?: HUDFrameProps;
  /** The stocks tray is dropped down from the island button. Default false. */
  stocksOpen?: boolean;
  paused?: boolean;
  speed?: GameSpeed;
  /** Which menu buttons show at the top right. */
  menu?: HUDMenuButtonsProps;
  /** The open build drawer; it highlights its category on the rail. */
  drawer?: BuildDrawerProps;
  /** The armed tool on the tool strip at the bottom. */
  tool?: ToolStripProps;
  /** The red rejection capsule above the tool strip. */
  rejection?: string;
  /** The parchment announcement; `onResume` makes it hold the game (the deficit hint). */
  banner?: { title: string; description: string; onResume?: () => void };
  /** The first-hour guide in the right column, as a card or (`collapsed`) a capsule. */
  firstSteps?: FirstStepsCardProps;
  /** Show the corner minimap. Default: on except on a phone. */
  minimap?: boolean;
  /** Inspector content (inspect mode only). */
  inspector?: InspectorProps;
  /** Show the iOS first-run "Long-press a tile to build" hint. */
  coachmark?: boolean;
  /** A pending touch placement: a ghost of `art` on an empty tile, centered low on screen under the nudge HUD. */
  placing?: {
    art: PlacedBuilding["art"];
    valid?: boolean;
    /** What the ghost's site reaches, in the count capsule over it: "18 trees in reach". */
    count?: { text: string; tone?: AreaCountTone };
    /** The gold ring on the ground, in map tiles; the ghost stands at (4, 4). */
    area?: AreaOfEffect;
  };
  /** Map props passed to `WorldBackdrop` (map, buildings, units, zoom, season, selected). */
  world?: Omit<WorldBackdropProps, "width" | "height" | "children">;
  /** A sheet presented over the game (GoalsPanel, ResearchPanel, StandingsPanel, PauseMenu ...). */
  sheet?: ReactNode;
  /** Any extra overlay. */
  children?: ReactNode;
}

const defaultHud: HUDFrameProps = {
  date: "Spring 1203",
  timeOfDay: "day",
  money: "$1,250",
  population: "84",
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
 * A whole in-game screen as the game lays it out: the status pill and menu
 * buttons along the top, the stocks tray and banners under them, the build
 * rail on the left (or the dock along the bottom in portrait) with its
 * drawer, the tool strip and rejection banner at the bottom, the minimap
 * in a corner, and optional touch overlays or a sheet. Start here for any
 * gameplay mock.
 */
export function GameScreen({
  width = 1180,
  height = 820,
  device = "pad",
  placement,
  hud = defaultHud,
  stocksOpen = false,
  paused = false,
  speed = 1,
  menu,
  drawer,
  tool,
  rejection,
  banner,
  firstSteps,
  minimap,
  inspector,
  coachmark,
  placing,
  world,
  sheet,
  children,
}: GameScreenProps) {
  const kind = device === "touch" ? "pad" : device;
  const touch = kind !== "mac";
  const phone = kind === "phone";
  const layout = placement ?? (width > height ? "rail" : "dock");
  const showsMinimap = minimap ?? !phone;
  const focusY = 0.62;
  const worldProps: Omit<WorldBackdropProps, "width" | "height" | "children"> =
    touch && placing
      ? {
          ...world,
          buildings: [...(world?.buildings ?? defaultTown), { art: placing.art, x: 4, y: 4, ghost: true }],
          center: { x: 4.5, y: 4.5 },
          focusY,
          // A red ghost shows no area, as it shows no count.
          area: (placing.valid ?? true) ? (placing.area ?? world?.area) : undefined,
        }
      : { ...world };
  const active: BuildRailItem | undefined =
    (drawer?.category as BuildRailItem | undefined) ?? (tool?.tool === "Road" || tool?.tool === "Demolish" ? (tool.tool as BuildRailItem) : undefined);
  const map = showsMinimap ? (
    <Minimap
      map={world?.map}
      buildings={(world?.buildings ?? defaultTown) as MinimapBuilding[]}
      camera={{ x: world?.center?.x ?? 7.5, y: world?.center?.y ?? 7.5, tilesAcross: width / (64 * (world?.zoom ?? 1.5)) * 2 }}
      device={kind === "mac" ? "mac" : phone ? "phone" : "pad"}
    />
  ) : null;
  const rail = <BuildRail placement={layout} active={active} phone={phone} hotkeys={kind === "mac"} />;
  const bottomStack = (
    <div className="cb-game__bottom-stack">
      {rejection ? <RejectionBanner message={rejection} /> : null}
      {tool && !drawer && !(phone && placing) ? <ToolStrip {...tool} /> : null}
    </div>
  );
  // A phone in portrait puts the pill on the left and folds the menu buttons into More.
  const folds = phone && layout === "dock";
  return (
    <WorldBackdrop width={width} height={height} {...worldProps}>
      <div className={`cb-game cb-game--${layout} ${phone ? "cb-game--phone" : ""}`}>
        <div className="cb-game__top">
          {folds ? null : <span className="cb-game__top-side" />}
          <StatusPill
            date={hud.date}
            timeOfDay={hud.timeOfDay}
            money={hud.money}
            population={hud.population.replace(/^Pop\.\s*/, "")}
            island={hud.island}
            stocksOpen={stocksOpen}
            paused={paused}
            speed={speed}
            device={kind}
          />
          <span className="cb-game__top-side cb-game__top-side--end">
            <HUDMenuButtons minimap={showsMinimap ? "shown" : "hidden"} folded={folds} {...menu} />
          </span>
        </div>
        <div className="cb-game__middle">
          <div className="cb-game__center">
            {stocksOpen && hud.island ? <StocksTray island={hud.island} stocks={hud.stocks ?? []} columns={phone ? 3 : 6} /> : null}
            {banner ? <SessionBanner title={banner.title} description={banner.description} onResume={banner.onResume} /> : null}
          </div>
          <div className="cb-game__right">
            {layout === "dock" ? map : null}
            {firstSteps ? <FirstStepsCard {...firstSteps} /> : null}
          </div>
        </div>
        {layout === "rail" ? (
          <>
            <div className="cb-game__rail">
              {rail}
              {drawer ? <BuildDrawer columns={phone ? 4 : 3} tileWidth={phone ? 78 : 92} {...drawer} /> : null}
            </div>
            <div className="cb-game__bottom">
              {!tool && inspector && inspector.lines.length > 0 ? <InspectorBlock inspector={inspector} touch={touch} /> : null}
              {bottomStack}
              {map}
            </div>
          </>
        ) : (
          <div className="cb-game__dock">
            {!tool && inspector && inspector.lines.length > 0 ? <InspectorBlock inspector={inspector} touch={touch} /> : null}
            {drawer ? <BuildDrawer columns={4} tileWidth={phone ? 78 : 92} {...drawer} /> : null}
            {bottomStack}
            {rail}
          </div>
        )}
      </div>
      {touch && placing ? (
        <div className="cb-game__placing">
          <PlacementHUD valid={placing.valid ?? true}>
            <span />
          </PlacementHUD>
        </div>
      ) : null}
      {touch && placing?.count && (placing.valid ?? true) ? (
        <div className="cb-game__count">
          <AreaCountCapsule text={placing.count.text} tone={placing.count.tone} />
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

function InspectorBlock({ inspector, touch }: { inspector: InspectorProps; touch: boolean }) {
  return (
    <div className="cb-game__inspector">
      <Inspector {...inspector} />
      {touch ? (
        <Button variant="bordered" icon="ellipsis.circle" style={{ background: "var(--cb-material)" }}>
          Actions
        </Button>
      ) : null}
    </div>
  );
}
