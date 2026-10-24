import "./SessionBanner.css";

export interface SessionBannerProps {
  /**
   * Headline: "The Renaissance age begins", "Steam engine is out of coal",
   * the idle-good hint "Nothing uses your planks", the deficit hint
   * "In the red: upkeep $40 vs tax $24".
   */
  title: string;
  /** One caption line under the title, centred; it may wrap. */
  description: string;
  /**
   * The banner holds the game until the player resumes (the deficit hint):
   * a leather Resume button under the caption.
   */
  onResume?: () => void;
}

/**
 * The parchment card announcing a history event, a new age, a finished
 * monument or a hint (a good piling up unused, the treasury in the red):
 * brown ink on cream with a 2px leather edge. The game's only non-system
 * surface; keep it for in-world announcements.
 */
export function SessionBanner({ title, description, onResume }: SessionBannerProps) {
  return (
    <div className="cb-session-banner" role="status">
      <div className="cb-session-banner__title">{title}</div>
      <div className="cb-session-banner__text">{description}</div>
      {onResume ? (
        <button type="button" className="cb-session-banner__resume" onClick={onResume}>
          Resume
        </button>
      ) : null}
    </div>
  );
}
