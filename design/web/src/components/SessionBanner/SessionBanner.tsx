import "./SessionBanner.css";

export interface SessionBannerProps {
  /** Headline: "The Renaissance age begins", "A harsh winter", "Steam engine is out of coal". */
  title: string;
  /** One caption line under the title. */
  description: string;
}

/**
 * The parchment card announcing a history event, a new age or a finished
 * monument: brown ink on cream with a 2px leather edge. The game's only
 * non-system surface; keep it for in-world announcements.
 */
export function SessionBanner({ title, description }: SessionBannerProps) {
  return (
    <div className="cb-session-banner" role="status">
      <div className="cb-session-banner__title">{title}</div>
      <div className="cb-session-banner__text">{description}</div>
    </div>
  );
}
