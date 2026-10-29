import { Button } from "../Button/Button";
import {
  WorldBackdrop,
  type PlacedBuilding,
} from "../WorldBackdrop/WorldBackdrop";
import "./ChapterCard.css";

/** Why a chapter was lost. Each reason has one fixed title. */
export type ChapterLostReason =
  | { kind: "deadline" }
  | { kind: "rivalRace"; rival: string }
  | { kind: "collapse" }
  | { kind: "bankruptcy" };

export interface ChapterCardProps {
  /** `intro` before the chapter, `ending` once it's won, `lost` once a lose condition fires. */
  variant: "intro" | "ending" | "lost";
  /** "The Long Chronicle". */
  campaign?: string;
  chapterNumber: number;
  /** "The Guild Charter". Ignored by `lost`, whose title is the reason. */
  title?: string;
  /** The intro or ending text, up to 320 characters. */
  text?: string;
  /** Intro: the goals, one line each ("20 merchants"). */
  goals?: string[];
  /** Intro: the bonus goals, listed after the goals as "Bonus: Treasury of $1,500". */
  bonus?: string[];
  /** Intro: the deadline row, e.g. `{ label: "Before 1210", remaining: "5 years, 3 seasons left" }`. */
  deadline?: { label: string; remaining: string };
  /** Ending: the difficulty it was won on. */
  difficulty?: "Easy" | "Normal" | "Hard";
  /** Ending: laurels earned of those on offer. */
  laurels?: { earned: number; of: number };
  /** Ending: "Decor “Founder’s stone”". */
  reward?: string;
  /** Ending: the next chapter's title. Omit at the end of a campaign: the main button reads "Back to chapters". */
  next?: string;
  /** Lost: why. */
  reason?: ChapterLostReason;
  /** Lost: one line of detail, e.g. "1210 began with “20 tools in store” unmet (14 of 20)." */
  detail?: string;
  /** The map header's town. Not drawn on `lost`. */
  town?: PlacedBuilding[];
  season?: "summer" | "autumn" | "winter";
  /** Width in px. Default 420 (intro), 360 (ending), 300 (lost). */
  width?: number;
  onBegin?: () => void;
  onNext?: () => void;
  onRetry?: () => void;
  onKeepBuilding?: () => void;
  /** Lost on bankruptcy: Close replaces Keep building. */
  onClose?: () => void;
  onBackToChapters?: () => void;
}

export function lostReasonTitle(reason: ChapterLostReason): string {
  switch (reason.kind) {
    case "deadline":
      return "The year turned before the goals were met";
    case "rivalRace":
      return `${reason.rival} got there first`;
    case "collapse":
      return "The town emptied out";
    case "bankruptcy":
      return "The treasury ran dry";
  }
}

const defaultWidth = { intro: 420, ending: 360, lost: 300 };

/**
 * The chapter cards: an iOS sheet with a render of the chapter's map at the
 * top. `intro` opens a chapter with its text, goals and Begin; `ending`
 * closes a won chapter with laurels, reward and Next; `lost` is the small
 * sheet with Retry, Keep building (Close after bankruptcy) and Back to chapters.
 */
export function ChapterCard(props: ChapterCardProps) {
  const {
    variant,
    campaign,
    chapterNumber,
    title,
    text,
    width = defaultWidth[variant],
  } = props;

  if (variant === "lost") {
    return (
      <article className="cb-chapter-card" style={{ width }}>
        <div className="cb-chapter-card__body cb-chapter-card__body--bare">
          <span className="cb-chapter-card__eyebrow">
            Chapter {chapterNumber} lost
          </span>
          <h2 className="cb-title3 cb-bold cb-chapter-card__title">
            {lostReasonTitle(props.reason ?? { kind: "deadline" })}
          </h2>
          {props.detail ? (
            <p className="cb-footnote cb-secondary cb-chapter-card__text">
              {props.detail}
            </p>
          ) : null}
          <Button variant="borderedProminent" fullWidth onClick={props.onRetry}>
            Retry chapter
          </Button>
          {props.reason?.kind === "bankruptcy" ? (
            <Button variant="bordered" fullWidth onClick={props.onClose}>
              Close
            </Button>
          ) : (
            <Button variant="bordered" fullWidth onClick={props.onKeepBuilding}>
              Keep building
            </Button>
          )}
          <Button
            variant="borderless"
            fullWidth
            onClick={props.onBackToChapters}
          >
            Back to chapters
          </Button>
        </div>
      </article>
    );
  }

  const intro = variant === "intro";
  return (
    <article className="cb-chapter-card" style={{ width }}>
      <div
        className="cb-chapter-card__map"
        style={{ height: intro ? 170 : 140 }}
      >
        <WorldBackdrop
          width={width}
          height={intro ? 170 : 140}
          zoom={1}
          center={{ x: 7, y: 7 }}
          buildings={props.town}
          season={props.season}
        />
      </div>
      <div className="cb-chapter-card__body">
        <span className="cb-chapter-card__eyebrow">
          {intro
            ? `${campaign ? `${campaign} · ` : ""}Chapter ${chapterNumber}`
            : `Chapter ${chapterNumber} won${props.difficulty ? ` · ${props.difficulty}` : ""}`}
        </span>
        <h2
          className={`${intro ? "cb-title" : "cb-title2"} cb-bold cb-chapter-card__title`}
        >
          {title}
        </h2>
        {text ? (
          <p
            className={`${intro ? "cb-body" : "cb-callout"} cb-chapter-card__text`}
          >
            {text}
          </p>
        ) : null}
        {intro ? (
          <>
            {props.goals?.length || props.bonus?.length || props.deadline ? (
              <div className="cb-chapter-card__group cb-callout">
                {props.goals?.map((goal) => (
                  <div key={goal} className="cb-chapter-card__row">
                    {goal}
                  </div>
                ))}
                {props.bonus?.map((goal) => (
                  <div key={`bonus-${goal}`} className="cb-chapter-card__row">
                    Bonus: {goal}
                  </div>
                ))}
                {props.deadline ? (
                  <div className="cb-chapter-card__row">
                    <span>{props.deadline.label}</span>
                    <span className="cb-secondary">
                      {props.deadline.remaining}
                    </span>
                  </div>
                ) : null}
              </div>
            ) : null}
            <Button
              variant="borderedProminent"
              size="large"
              fullWidth
              onClick={props.onBegin}
            >
              Begin
            </Button>
          </>
        ) : (
          <>
            {props.laurels || props.reward ? (
              <div className="cb-chapter-card__group cb-callout">
                {props.laurels ? (
                  <div className="cb-chapter-card__row">
                    <span>Laurels</span>
                    <span className="cb-mono cb-semibold">
                      {props.laurels.earned} of {props.laurels.of}
                    </span>
                  </div>
                ) : null}
                {props.reward ? (
                  <div className="cb-chapter-card__row">
                    <span>Reward</span>
                    <span>{props.reward}</span>
                  </div>
                ) : null}
              </div>
            ) : null}
            <Button
              variant="borderedProminent"
              size="large"
              fullWidth
              onClick={props.next ? props.onNext : props.onBackToChapters}
            >
              {props.next ? `Next: ${props.next}` : "Back to chapters"}
            </Button>
            <Button
              variant="borderless"
              fullWidth
              onClick={props.onKeepBuilding}
            >
              Keep building
            </Button>
          </>
        )}
      </div>
    </article>
  );
}
