import {
  ChapterCard,
  CityProvider,
  WorldBackdrop,
  type PlacedBuilding,
} from "@citybuilder/ui";
import type { ReactNode } from "react";

const guildTown: PlacedBuilding[] = [
  { art: "town-center", x: 5, y: 5 },
  { art: "guild-hall", x: 8, y: 6 },
  { art: "toolsmith", x: 5, y: 9 },
  { art: "house-tier2", x: 9, y: 9 },
  { art: "smelter", x: 2, y: 8 },
];

const monumentTown: PlacedBuilding[] = [
  { art: "monument", x: 7, y: 6 },
  { art: "bakery", x: 4, y: 8 },
  { art: "quern-house", x: 9, y: 9 },
  { art: "house", x: 6, y: 10 },
  { art: "house", x: 10, y: 6 },
];

/** The cards present over a dimmed map, as in the game. */
const OverMap = ({
  height = 820,
  children,
}: {
  height?: number;
  children: ReactNode;
}) => (
  <WorldBackdrop width={1180} height={height} zoom={2}>
    <div
      style={{
        position: "absolute",
        inset: 0,
        background: "var(--cb-scrim)",
        display: "flex",
        alignItems: "center",
        justifyContent: "center",
      }}
    >
      {children}
    </div>
  </WorldBackdrop>
);

export const Intro = () => (
  <OverMap>
    <ChapterCard
      variant="intro"
      campaign="The Long Chronicle"
      chapterNumber={3}
      title="The Guild Charter"
      text="Merchants will not settle where there are no tools to buy and no guild to vouch for them. The charter is yours if the town can earn it: smiths, a guild hall, and full stalls in the market."
      goals={["Research Metallurgy", "Own a guild hall", "20 merchants", "20 tools in store"]}
      bonus={["30 merchants", "30 tools in store", "20 merchants for a season"]}
      deadline={{ label: "Before 1210", remaining: "6 years, 3 seasons left" }}
      town={guildTown}
    />
  </OverMap>
);

export const Ending = () => (
  <OverMap height={640}>
    <ChapterCard
      variant="ending"
      chapterNumber={2}
      difficulty="Normal"
      title="Bread and Stone"
      text="The monument stands on the hill, raised on bread and sweat. Every table has a loaf, and the scholars say a new age is turning."
      laurels={{ earned: 1, of: 2 }}
      reward="Decor “Founder’s stone”"
      next="The Guild Charter"
      town={monumentTown}
      season="autumn"
    />
  </OverMap>
);

export const EndingLastChapter = () => (
  <OverMap height={640}>
    <ChapterCard
      variant="ending"
      chapterNumber={6}
      difficulty="Hard"
      title="The Electric Age"
      text="At dusk the windows light up all at once. From a single hearth to a town that glows, the chronicle is complete."
      laurels={{ earned: 2, of: 2 }}
      reward="Banner “Lightning”"
      town={[
        { art: "power-plant", x: 7, y: 6 },
        { art: "steam-engine", x: 4, y: 8 },
        { art: "house-tier3", x: 9, y: 9 },
        { art: "house-tier3", x: 6, y: 10 },
      ]}
    />
  </OverMap>
);

export const LostDeadline = () => (
  <OverMap height={460}>
    <ChapterCard
      variant="lost"
      chapterNumber={3}
      reason={{ kind: "deadline" }}
      detail="1210 began with “20 tools in store” unmet."
    />
  </OverMap>
);

export const LostReasons = () => (
  <OverMap height={460}>
    <div style={{ display: "flex", gap: 20 }}>
      <ChapterCard
        variant="lost"
        chapterNumber={4}
        reason={{ kind: "rivalRace", rival: "Ravenshore" }}
        detail="A rival town reached the race goal before yours. You can keep building, or try again."
      />
      <ChapterCard
        variant="lost"
        chapterNumber={1}
        reason={{ kind: "collapse" }}
        detail="Too few residents stayed for a whole season. You can keep building, or try again."
      />
      <ChapterCard
        variant="lost"
        chapterNumber={2}
        reason={{ kind: "bankruptcy" }}
        detail="The treasury stayed in the red too long. You can still save from the pause menu."
      />
    </div>
  </OverMap>
);

export const Dark = () => (
  <CityProvider theme="dark">
    <OverMap>
      <ChapterCard
        variant="intro"
        campaign="Hard Ground"
        chapterNumber={1}
        title="The Thin Forest"
        text="Goats and old fires have stripped these hills. Every tree is precious. Plant before you cut, build what pays, and let the forum's coin carry the rest."
        goals={["30 citizens", "Own 4 foresters", "30 residents for a season"]}
        bonus={["Own a forum", "Treasury of $1,000"]}
        deadline={{ label: "Before 1206", remaining: "2 years, 3 seasons left" }}
        town={[
          { art: "town-center", x: 5, y: 5 },
          { art: "forester", x: 8, y: 6 },
          { art: "forum", x: 4, y: 9 },
          { art: "house", x: 9, y: 9 },
        ]}
      />
    </OverMap>
  </CityProvider>
);
