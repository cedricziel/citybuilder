import { useState, type ReactNode } from "react";
import { Button } from "../Button/Button";
import { MenuPicker } from "../MenuPicker/MenuPicker";
import { SegmentedPicker } from "../SegmentedPicker/SegmentedPicker";
import { Sheet } from "../Sheet/Sheet";
import "./NewGameDialog.css";

export type GameMode = "Sandbox" | "Scenario";

export interface NewGameDialogProps {
  /** Initial mode. Sandbox shows starting age and difficulty; Scenario shows the scenario picker. */
  mode?: GameMode;
  layout?: "Single Island" | "Archipelago";
  seedMode?: "Default" | "Random" | "Custom";
  /** The rolled seed (Random) or typed text (Custom). */
  seed?: string;
  culture?: string;
  age?: string;
  difficulty?: "Easy" | "Normal" | "Hard";
  scenario?: string;
  /** Disable Start (e.g. a custom seed that isn't a number). */
  startDisabled?: boolean;
  width?: number;
  onStart?: () => void;
  onCancel?: () => void;
}

const cultures: Record<string, string> = {
  "Northern European": "Half-timbered towns under steep tiled roofs.",
  Mediterranean: "Whitewashed walls, terracotta roofs and bell towers.",
  "East Asian": "Timber halls under dark, wide-eaved roofs.",
  "Middle Eastern": "Sandstone, flat roofs and domes.",
};

const ages: Record<string, string> = {
  Antiquity: "Stone towns, hand mills and the first libraries.",
  Medieval: "Timber and tile, windmills and guilds.",
  Renaissance: "Printing, trade and tall stuccoed fronts.",
  Industrial: "Steam, brick and smoking chimneys.",
  Modern: "Electricity and concrete.",
};

const scenarios: Record<string, { blurb: string; meta: string }> = {
  "First Harvest": { blurb: "Grow an Antiquity village to 40 people and store 20 bread.", meta: "Antiquity · Easy" },
  "The Guild Town": { blurb: "Raise 30 merchants and stock 30 tools.", meta: "Medieval · Normal" },
  "Steam and Smoke": { blurb: "Lead a Renaissance town into the Industrial age.", meta: "Renaissance · Hard" },
};

function Section({ title, children }: { title: string; children: ReactNode }) {
  return (
    <div className="cb-newgame__section">
      <div className="cb-newgame__heading">{title}</div>
      {children}
    </div>
  );
}

/**
 * The "New Game" sheet from the title screen: mode, world layout, seed,
 * culture, then starting age and difficulty (sandbox) or a scenario.
 * Interactive: the pickers switch locally from the initial props.
 */
export function NewGameDialog(props: NewGameDialogProps) {
  const [mode, setMode] = useState<string>(props.mode ?? "Sandbox");
  const [layout, setLayout] = useState<string>(props.layout ?? "Single Island");
  const [seedMode, setSeedMode] = useState<string>(props.seedMode ?? "Default");
  const [culture, setCulture] = useState(props.culture ?? "Northern European");
  const [age, setAge] = useState(props.age ?? "Medieval");
  const [difficulty, setDifficulty] = useState<string>(props.difficulty ?? "Normal");
  const [scenario, setScenario] = useState(props.scenario ?? "First Harvest");
  const seed = props.seed ?? (seedMode === "Random" ? "8817263540129" : "");

  return (
    <Sheet doneLabel={null} background="plain" width={props.width}>
      <div className="cb-newgame">
        <div className="cb-newgame__title">New Game</div>
        <SegmentedPicker label="Mode" options={["Sandbox", "Scenario"]} selected={mode} onChange={setMode} />
        <Section title="World layout">
          <SegmentedPicker label="Layout" options={["Single Island", "Archipelago"]} selected={layout} onChange={setLayout} />
        </Section>
        <Section title="Seed">
          <SegmentedPicker label="Seed mode" options={["Default", "Random", "Custom"]} selected={seedMode} onChange={setSeedMode} />
          {seedMode === "Default" ? <div className="cb-newgame__note">Seed: 0 (same world every time)</div> : null}
          {seedMode === "Random" ? (
            <div className="cb-newgame__seed">
              <span className="cb-newgame__note cb-mono">Seed: {seed}</span>
              <Button variant="borderless" size="small">
                Re-roll
              </Button>
            </div>
          ) : null}
          {seedMode === "Custom" ? <input className="cb-newgame__field" placeholder="Decimal seed (UInt64)" defaultValue={seed} /> : null}
        </Section>
        <Section title="Culture">
          <MenuPicker options={Object.keys(cultures)} selected={culture} onChange={setCulture} />
          <div className="cb-newgame__blurb">{cultures[culture]}</div>
        </Section>
        {mode === "Sandbox" ? (
          <>
            <Section title="Starting age">
              <MenuPicker options={Object.keys(ages)} selected={age} onChange={setAge} />
              <div className="cb-newgame__blurb">{ages[age]}</div>
            </Section>
            <Section title="Difficulty">
              <SegmentedPicker label="Difficulty" options={["Easy", "Normal", "Hard"]} selected={difficulty} onChange={setDifficulty} />
            </Section>
          </>
        ) : (
          <Section title="Scenario">
            <MenuPicker options={Object.keys(scenarios)} selected={scenario} onChange={setScenario} />
            <div className="cb-newgame__blurb">{scenarios[scenario]?.blurb}</div>
            <div className="cb-newgame__blurb cb-semibold">{scenarios[scenario]?.meta}</div>
          </Section>
        )}
        <div className="cb-newgame__actions">
          <Button variant="borderless" onClick={props.onCancel}>
            Cancel
          </Button>
          <Button variant="borderedProminent" disabled={props.startDisabled} onClick={props.onStart}>
            Start
          </Button>
        </div>
      </div>
    </Sheet>
  );
}
