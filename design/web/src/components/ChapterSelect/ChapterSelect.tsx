import { useState } from "react";
import type { BuildingArt } from "../BuildingSprite/BuildingSprite";
import { BuildingSprite } from "../BuildingSprite/BuildingSprite";
import { Button } from "../Button/Button";
import { Glass } from "../Glass/Glass";
import { Icon } from "../Icon/Icon";
import { MenuPicker } from "../MenuPicker/MenuPicker";
import { SegmentedPicker } from "../SegmentedPicker/SegmentedPicker";
import { Sheet } from "../Sheet/Sheet";
import {
  WorldBackdrop,
  type PlacedBuilding,
} from "../WorldBackdrop/WorldBackdrop";
import "./ChapterSelect.css";

export type Difficulty = "Easy" | "Normal" | "Hard";

/** Where the player stands with a chapter. */
export type ChapterStatus =
  /** Won: "Won on Normal · 2 laurels", green with a check. */
  | { kind: "won"; difficulty: Difficulty; laurels: number }
  /** Playable: "Open" in accent. */
  | { kind: "open" }
  /** Locked behind another chapter: `key` reads "Win chapter 2" or "Win The Long Chronicle chapter 3". */
  | { kind: "locked"; key: string }
  /** Waiting on a feature that hasn't shipped: "Coming later". */
  | { kind: "later" };

export interface ChapterInfo {
  id: string;
  number: number;
  title: string;
  status: ChapterStatus;
  /** The chapter's signature building: the row thumbnail and the map header's centre. */
  art: BuildingArt;
  /** The intro text from the chapter's card. */
  intro?: string;
  goals?: string[];
  /** One laurel each. */
  bonus?: string[];
  /** "Medieval, 1203, no rivals". */
  start?: string;
  /** "1210 begins, or bankruptcy". */
  lostIf?: string;
  /** The culture the chapter fixes, e.g. "Mediterranean". Omit when the player picks. */
  culture?: string;
  /** The difficulties the chapter offers. Default all three. */
  difficulties?: Difficulty[];
  /** "Banner “Guild key”. Opens The Merchant Sea and Hard Ground." */
  reward?: string;
  /** The map header's town. Default: the signature building with a few houses. */
  town?: PlacedBuilding[];
}

export interface CampaignInfo {
  id: string;
  title: string;
  chapters: ChapterInfo[];
}

export interface ChapterSelectProps {
  /** The campaigns in order. An empty list shows the calm "on its way" state. */
  campaigns: CampaignInfo[];
  /** The chosen chapter's id. Default: the first open chapter. */
  selected?: string;
  /** iPhone: a "Campaigns" sheet listing the chapters with sprite thumbnails, no detail pane. */
  compact?: boolean;
  difficulty?: Difficulty;
  /** The culture picked for chapters that leave it open. */
  culture?: string;
  width?: number;
  height?: number;
  onSelect?: (chapterId: string) => void;
  onStart?: (
    chapterId: string,
    difficulty: Difficulty,
    culture: string,
  ) => void;
  onClose?: () => void;
}

const cultures = ["Northern European", "Mediterranean", "East Asian", "Middle Eastern"];
const allDifficulties: Difficulty[] = ["Easy", "Normal", "Hard"];

function statusLine(status: ChapterStatus): string {
  switch (status.kind) {
    case "won":
      return `Won on ${status.difficulty} · ${status.laurels} ${status.laurels === 1 ? "laurel" : "laurels"}`;
    case "open":
      return "Open";
    case "locked":
      return status.key;
    case "later":
      return "Coming later";
  }
}

function StatusMark({ status, size }: { status: ChapterStatus; size: number }) {
  if (status.kind === "won")
    return (
      <Icon name="checkmark.circle.fill" size={size} color="var(--cb-green)" />
    );
  if (status.kind === "locked" || status.kind === "later")
    return (
      <Icon name="lock.fill" size={size} color="var(--cb-tertiary-label)" />
    );
  return null;
}

function wonCount(campaign: CampaignInfo): number {
  return campaign.chapters.filter((chapter) => chapter.status.kind === "won")
    .length;
}

function firstOpen(campaigns: CampaignInfo[]): string | undefined {
  const chapters = campaigns.flatMap((campaign) => campaign.chapters);
  return (
    chapters.find((chapter) => chapter.status.kind === "open") ?? chapters[0]
  )?.id;
}

function defaultTown(art: BuildingArt): PlacedBuilding[] {
  return [
    { art: "town-center", x: 4, y: 5 },
    { art, x: 7, y: 6 },
    { art: "house", x: 5, y: 9 },
    { art: "house-tier2", x: 9, y: 9 },
    { art: "house", x: 10, y: 6 },
  ];
}

function EmptyState({ titled }: { titled: boolean }) {
  return (
    <div className="cb-chapters-empty">
      <Icon name="map" size={34} color="var(--cb-tertiary-label)" />
      {titled ? <div className="cb-chapters-empty__title">Campaigns</div> : null}
      <div className="cb-chapters-empty__text">
        The first campaign is on its way. Chapters will appear here with a
        coming update.
      </div>
    </div>
  );
}

function CompactList({
  campaigns,
  onSelect,
}: {
  campaigns: CampaignInfo[];
  onSelect: (id: string) => void;
}) {
  return (
    <div className="cb-chapters-compact">
      {campaigns.map((campaign) => (
        <section key={campaign.id} className="cb-chapters-group">
          <div className="cb-chapters-group__header cb-chapters-group__header--compact">
            <span>{campaign.title}</span>
            <span className="cb-mono">
              {wonCount(campaign)} of {campaign.chapters.length} won
            </span>
          </div>
          <div className="cb-chapters-group__list">
            {campaign.chapters.map((chapter) => (
              <button
                key={chapter.id}
                type="button"
                className={`cb-chapter-row cb-chapter-row--compact cb-chapter-row--${chapter.status.kind}`}
                onClick={() => onSelect(chapter.id)}
              >
                <span className="cb-chapter-row__thumb">
                  <BuildingSprite building={chapter.art} scale={0.42} />
                </span>
                <span className="cb-chapter-row__text">
                  <span className="cb-body">
                    {chapter.number}. {chapter.title}
                  </span>
                  <span
                    className={`cb-footnote cb-chapter-status cb-chapter-status--${chapter.status.kind}`}
                  >
                    {statusLine(chapter.status)}
                  </span>
                </span>
                <StatusMark status={chapter.status} size={18} />
              </button>
            ))}
          </div>
        </section>
      ))}
    </div>
  );
}

function Detail({
  campaign,
  chapter,
  difficulty,
  culture,
  onDifficulty,
  onCulture,
  onStart,
}: {
  campaign: CampaignInfo;
  chapter: ChapterInfo;
  difficulty: Difficulty;
  culture: string;
  onDifficulty: (difficulty: Difficulty) => void;
  onCulture: (culture: string) => void;
  onStart: () => void;
}) {
  const playable =
    chapter.status.kind === "open" || chapter.status.kind === "won";
  return (
    <main className="cb-chapter-detail">
      <div className="cb-chapter-detail__map">
        <WorldBackdrop
          height={300}
          zoom={1}
          center={{ x: 7, y: 7 }}
          buildings={chapter.town ?? defaultTown(chapter.art)}
        />
        <Glass
          shape="capsule"
          padding="4px 12px"
          className="cb-caption cb-semibold cb-chapter-detail__eyebrow"
        >
          {campaign.title} · Chapter {chapter.number}
        </Glass>
      </div>
      <div className="cb-chapter-detail__body">
        <div className="cb-chapter-detail__story">
          <span className="cb-large-title cb-bold">{chapter.title}</span>
          {chapter.intro ? (
            <span className="cb-body cb-chapter-detail__intro">
              {chapter.intro}
            </span>
          ) : null}
          {chapter.goals && chapter.goals.length > 0 ? (
            <div className="cb-chapter-detail__list">
              <span className="cb-chapter-detail__heading">Goals</span>
              {chapter.goals.map((goal) => (
                <span key={goal} className="cb-callout">
                  {goal}
                </span>
              ))}
            </div>
          ) : null}
          {chapter.bonus && chapter.bonus.length > 0 ? (
            <div className="cb-chapter-detail__list">
              <span className="cb-chapter-detail__heading">
                Bonus · one laurel each
              </span>
              {chapter.bonus.map((goal) => (
                <span key={goal} className="cb-callout cb-secondary">
                  {goal}
                </span>
              ))}
            </div>
          ) : null}
        </div>
        <div className="cb-chapter-detail__side">
          {chapter.start ? (
            <div className="cb-chapter-detail__fact">
              <span className="cb-footnote cb-secondary">Starts</span>
              <span className="cb-headline">{chapter.start}</span>
            </div>
          ) : null}
          {chapter.lostIf ? (
            <div className="cb-chapter-detail__fact">
              <span className="cb-footnote cb-secondary">Lost if</span>
              <span className="cb-headline">{chapter.lostIf}</span>
            </div>
          ) : null}
          <div className="cb-chapter-detail__picker">
            <span className="cb-footnote cb-secondary">Difficulty</span>
            <SegmentedPicker
              label="Difficulty"
              options={chapter.difficulties ?? allDifficulties}
              selected={difficulty}
              onChange={(value) => onDifficulty(value as Difficulty)}
            />
          </div>
          {chapter.culture ? (
            <div className="cb-chapter-detail__fact">
              <span className="cb-footnote cb-secondary">Culture</span>
              <span className="cb-headline">{chapter.culture}</span>
            </div>
          ) : (
            <div className="cb-chapter-detail__picker">
              <span className="cb-footnote cb-secondary">Culture</span>
              <MenuPicker
                options={cultures}
                selected={culture}
                onChange={onCulture}
              />
            </div>
          )}
          {chapter.reward ? (
            <span className="cb-footnote cb-secondary">
              Reward: {chapter.reward}
            </span>
          ) : null}
          {playable ? (
            <Button
              variant="borderedProminent"
              size="large"
              fullWidth
              onClick={onStart}
            >
              Start chapter
            </Button>
          ) : (
            <Button
              variant="borderedProminent"
              size="large"
              fullWidth
              disabled
              icon="lock.fill"
            >
              {statusLine(chapter.status)}
            </Button>
          )}
        </div>
      </div>
    </main>
  );
}

/**
 * The campaign chapter select. On iPad and Mac a split view: campaigns and
 * their chapters on the left, the chosen chapter on the right with its map,
 * intro, goals, limits, pickers and Start. With `compact` (iPhone) it is a
 * "Campaigns" sheet listing the chapters; choosing one pushes its detail.
 * Interactive: selection and pickers switch locally from the initial props.
 */
export function ChapterSelect({
  campaigns,
  selected,
  compact,
  difficulty: initialDifficulty = "Normal",
  culture: initialCulture = "Northern European",
  width,
  height,
  onSelect,
  onStart,
  onClose,
}: ChapterSelectProps) {
  const [chosen, setChosen] = useState(selected ?? firstOpen(campaigns));
  const [difficulty, setDifficulty] = useState<Difficulty>(initialDifficulty);
  const [culture, setCulture] = useState(initialCulture);
  const empty = campaigns.every((campaign) => campaign.chapters.length === 0);

  const choose = (id: string) => {
    setChosen(id);
    onSelect?.(id);
  };

  if (compact) {
    return (
      <Sheet
        title="Campaigns"
        doneLabel="Close"
        onDone={onClose}
        width={width}
        height={height}
      >
        {empty ? (
          <EmptyState titled={false} />
        ) : (
          <CompactList campaigns={campaigns} onSelect={choose} />
        )}
      </Sheet>
    );
  }

  if (empty) {
    return (
      <div className="cb-chapters cb-chapters--empty" style={{ width, height }}>
        <EmptyState titled />
      </div>
    );
  }

  const campaign =
    campaigns.find((c) =>
      c.chapters.some((chapter) => chapter.id === chosen),
    ) ?? campaigns[0];
  const chapter =
    campaign.chapters.find((c) => c.id === chosen) ?? campaign.chapters[0];

  const allowed = chapter.difficulties ?? allDifficulties;
  const offered = allowed.includes(difficulty) ? difficulty : allowed[0];

  return (
    <div className="cb-chapters" style={{ width, height }}>
      <nav className="cb-chapters__nav" aria-label="Chapters">
        <span className="cb-large-title cb-bold cb-chapters__title">
          Campaigns
        </span>
        {campaigns.map((c) => (
          <section key={c.id} className="cb-chapters-group">
            <div className="cb-chapters-group__header">
              <span>{c.title}</span>
              <span className="cb-mono">
                {wonCount(c)}/{c.chapters.length}
              </span>
            </div>
            <div className="cb-chapters-group__list">
              {c.chapters.map((ch) => (
                <button
                  key={ch.id}
                  type="button"
                  className={`cb-chapter-row cb-chapter-row--${ch.status.kind}${ch.id === chapter.id ? " cb-chapter-row--selected" : ""}`}
                  aria-current={ch.id === chapter.id || undefined}
                  onClick={() => choose(ch.id)}
                >
                  <span className="cb-subheadline cb-mono cb-chapter-row__number">
                    {ch.number}
                  </span>
                  <span className="cb-chapter-row__text">
                    <span className="cb-subheadline">{ch.title}</span>
                    <span
                      className={`cb-caption cb-chapter-status cb-chapter-status--${ch.status.kind}`}
                    >
                      {statusLine(ch.status)}
                    </span>
                  </span>
                  <StatusMark status={ch.status} size={15} />
                </button>
              ))}
            </div>
          </section>
        ))}
      </nav>
      <Detail
        campaign={campaign}
        chapter={chapter}
        difficulty={offered}
        culture={culture}
        onDifficulty={setDifficulty}
        onCulture={setCulture}
        onStart={() => onStart?.(chapter.id, offered, chapter.culture ?? culture)}
      />
    </div>
  );
}
