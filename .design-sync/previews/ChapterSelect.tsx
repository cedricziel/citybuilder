import {
  ChapterSelect,
  CityProvider,
  type CampaignInfo,
  type ChapterStatus,
} from "@citybuilder/ui";

const won = (
  difficulty: "Easy" | "Normal" | "Hard",
  laurels: number,
): ChapterStatus => ({ kind: "won", difficulty, laurels });
const open: ChapterStatus = { kind: "open" };
const locked = (key: string): ChapterStatus => ({ kind: "locked", key });
const later: ChapterStatus = { kind: "later" };

const campaigns: CampaignInfo[] = [
  {
    id: "chronicle",
    title: "The Long Chronicle",
    chapters: [
      {
        id: "chronicle-1",
        number: 1,
        title: "First Fires",
        art: "house",
        status: won("Normal", 2),
      },
      {
        id: "chronicle-2",
        number: 2,
        title: "Bread and Stone",
        art: "monument",
        status: won("Easy", 1),
      },
      {
        id: "chronicle-3",
        number: 3,
        title: "The Guild Charter",
        art: "guild-hall",
        status: open,
        intro:
          "Merchants will not settle where there are no tools to buy and no guild to vouch for them. The charter is yours if the town can earn it: smiths, a guild hall, and full stalls in the market.",
        goals: [
          "Research Metallurgy",
          "Own a guild hall",
          "20 merchants",
          "20 tools in store",
        ],
        bonus: ["30 merchants and 30 tools", "Hold 20 merchants for a season"],
        start: "Medieval, 1203, no rivals",
        lostIf: "1210 begins, or bankruptcy",
        reward: "banner “Guild key”. Opens The Merchant Sea and Hard Ground.",
        town: [
          { art: "town-center", x: 5, y: 5 },
          { art: "guild-hall", x: 8, y: 6 },
          { art: "toolsmith", x: 5, y: 9 },
          { art: "house-tier2", x: 9, y: 9 },
          { art: "house-tier2", x: 11, y: 8 },
          { art: "smelter", x: 2, y: 8 },
        ],
      },
      {
        id: "chronicle-4",
        number: 4,
        title: "Across the Water",
        art: "port-n",
        status: locked("Win chapter 3"),
      },
      {
        id: "chronicle-5",
        number: 5,
        title: "Steam and Smoke",
        art: "steam-engine",
        status: locked("Win chapter 4"),
      },
      {
        id: "chronicle-6",
        number: 6,
        title: "The Electric Age",
        art: "power-plant",
        status: locked("Win chapter 5"),
      },
    ],
  },
  {
    id: "merchant-sea",
    title: "The Merchant Sea",
    chapters: [
      {
        id: "sea-1",
        number: 1,
        title: "Two Shores",
        art: "shipyard-n",
        status: locked("Win The Long Chronicle chapter 3"),
      },
      {
        id: "sea-2",
        number: 2,
        title: "The Far Vein",
        art: "mine",
        status: locked("Win chapter 1"),
      },
      {
        id: "sea-3",
        number: 3,
        title: "Orders from the Mainland",
        art: "port-e",
        status: later,
      },
      {
        id: "sea-4",
        number: 4,
        title: "The Printing Race",
        art: "library",
        status: locked("Win chapter 2"),
      },
      {
        id: "sea-5",
        number: 5,
        title: "Mistress of the Sea",
        art: "shipyard-e",
        status: locked("Win chapter 4"),
      },
    ],
  },
  {
    id: "hard-ground",
    title: "Hard Ground",
    chapters: [
      {
        id: "hard-1",
        number: 1,
        title: "The Thin Forest",
        art: "forester",
        status: open,
        intro:
          "Goats and old fires have stripped these hills. Every tree is precious. Plant before you cut, build what pays, and let the forum's coin carry the rest.",
        goals: [
          "30 citizens",
          "Own 4 foresters",
          "Hold 30 residents for a season",
        ],
        bonus: ["Own a forum", "Treasury of $1,000"],
        start: "Medieval, 1203, no rivals",
        lostIf: "1206 begins, the town falls below 25, or bankruptcy",
        culture: "Mediterranean",
        reward: "map preset “The Thin Forest”.",
        town: [
          { art: "town-center", x: 5, y: 5 },
          { art: "forester", x: 8, y: 6 },
          { art: "forum", x: 4, y: 9 },
          { art: "house", x: 9, y: 9 },
          { art: "lumberjack-hut", x: 11, y: 7 },
        ],
      },
      {
        id: "hard-2",
        number: 2,
        title: "The Long Winter",
        art: "mead-hall",
        status: later,
      },
      {
        id: "hard-3",
        number: 3,
        title: "The Long Road",
        art: "caravanserai",
        status: later,
      },
      {
        id: "hard-4",
        number: 4,
        title: "Fire and Fever",
        art: "temple-garden",
        status: later,
      },
    ],
  },
];

export const SplitView = () => (
  <ChapterSelect
    width={1180}
    height={820}
    campaigns={campaigns}
    selected="chronicle-3"
  />
);

export const FixedCulture = () => (
  <ChapterSelect
    width={1180}
    height={820}
    campaigns={campaigns}
    selected="hard-1"
    difficulty="Hard"
  />
);

export const LockedChapter = () => (
  <ChapterSelect
    width={1180}
    height={820}
    campaigns={campaigns}
    selected="chronicle-4"
  />
);

export const Compact = () => (
  <ChapterSelect compact width={390} height={760} campaigns={campaigns} />
);

export const Empty = () => (
  <ChapterSelect width={1180} height={820} campaigns={[]} />
);

export const EmptyCompact = () => (
  <ChapterSelect compact width={390} height={420} campaigns={[]} />
);

export const Dark = () => (
  <CityProvider theme="dark">
    <ChapterSelect
      width={1180}
      height={820}
      campaigns={campaigns}
      selected="chronicle-3"
    />
  </CityProvider>
);
