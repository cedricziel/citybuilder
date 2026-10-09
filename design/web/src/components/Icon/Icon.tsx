import type { CSSProperties, ReactElement } from "react";

/** SF Symbol names the app uses, drawn as inline SVG. */
export type IconName =
  | "pause.fill"
  | "play.fill"
  | "gearshape.fill"
  | "gear"
  | "book.fill"
  | "flag.checkered"
  | "lock.fill"
  | "checkmark"
  | "checkmark.circle.fill"
  | "circle"
  | "xmark"
  | "hand.tap"
  | "ellipsis.circle"
  | "laurel.leading"
  | "house"
  | "power"
  | "tray.and.arrow.down"
  | "sun.max.fill"
  | "sunrise.fill"
  | "sunset.fill"
  | "moon.stars.fill"
  | "arrow.up.right"
  | "arrow.down.right"
  | "arrow.down.left"
  | "arrow.up.left"
  | "chevron.down"
  | "chevron.right"
  | "hammer.fill";

export interface IconProps {
  /** The SF Symbol name as written in the Swift code, e.g. `"flag.checkered"`. */
  name: IconName;
  /** Glyph size in px (the symbol's point size). Default 17, body text. */
  size?: number;
  /** Any CSS color; defaults to the current text color. */
  color?: string;
  /** Accessible label. Omit for decorative icons next to text. */
  label?: string;
  style?: CSSProperties;
}

const stroke = { fill: "none", stroke: "currentColor", strokeWidth: 2, strokeLinecap: "round", strokeLinejoin: "round" } as const;

function arrow(rotate: number): ReactElement {
  return (
    <g transform={`rotate(${rotate} 12 12)`} {...stroke} strokeWidth={2.6}>
      <path d="M6 18 18 6" />
      <path d="M8.5 6H18v9.5" />
    </g>
  );
}

const glyphs: Record<IconName, ReactElement> = {
  "pause.fill": (
    <g fill="currentColor">
      <rect x="6" y="4" width="4.2" height="16" rx="1.2" />
      <rect x="13.8" y="4" width="4.2" height="16" rx="1.2" />
    </g>
  ),
  "play.fill": <path fill="currentColor" d="M7 4.6v14.8c0 .8.9 1.3 1.6.9l12-7.4c.6-.4.6-1.4 0-1.8l-12-7.4C7.9 3.3 7 3.8 7 4.6Z" />,
  "gearshape.fill": (
    <g fill="currentColor">
      <path
        fillRule="evenodd"
        d="M10.3 2h3.4l.5 2.6 1.6.7 2.2-1.5 2.4 2.4-1.5 2.2.7 1.6 2.6.5v3.4l-2.6.5-.7 1.6 1.5 2.2-2.4 2.4-2.2-1.5-1.6.7-.5 2.6h-3.4l-.5-2.6-1.6-.7-2.2 1.5-2.4-2.4 1.5-2.2-.7-1.6L2 13.7v-3.4l2.6-.5.7-1.6-1.5-2.2 2.4-2.4 2.2 1.5 1.6-.7ZM12 8.4a3.6 3.6 0 1 0 0 7.2 3.6 3.6 0 0 0 0-7.2Z"
      />
    </g>
  ),
  gear: (
    <g {...stroke} strokeWidth={1.6}>
      <path d="M10.3 2.8h3.4l.5 2.3 1.6.7 2-1.3 2.4 2.4-1.3 2 .7 1.6 2.3.5v3.4l-2.3.5-.7 1.6 1.3 2-2.4 2.4-2-1.3-1.6.7-.5 2.3h-3.4l-.5-2.3-1.6-.7-2 1.3-2.4-2.4 1.3-2-.7-1.6-2.3-.5v-3.4l2.3-.5.7-1.6-1.3-2 2.4-2.4 2 1.3 1.6-.7Z" />
      <circle cx="12" cy="12" r="3.2" />
    </g>
  ),
  "book.fill": (
    <g fill="currentColor">
      <path d="M11.2 6.3C9 4.6 6 4.1 2.6 4.6c-.4.1-.6.4-.6.8v12.9c0 .5.4.8.9.7 3-.5 5.7 0 8.3 1.6Z" />
      <path d="M12.8 6.3c2.2-1.7 5.2-2.2 8.6-1.7.4.1.6.4.6.8v12.9c0 .5-.4.8-.9.7-3-.5-5.7 0-8.3 1.6Z" />
    </g>
  ),
  "flag.checkered": (
    <g>
      <path d="M5 21V3.5" {...stroke} />
      <rect x="5.8" y="4" width="14" height="10" rx="1" fill="none" stroke="currentColor" strokeWidth="1.6" />
      <g fill="currentColor">
        <rect x="5.8" y="4" width="3.5" height="3.33" />
        <rect x="12.8" y="4" width="3.5" height="3.33" />
        <rect x="9.3" y="7.33" width="3.5" height="3.33" />
        <rect x="16.3" y="7.33" width="3.5" height="3.33" />
        <rect x="5.8" y="10.66" width="3.5" height="3.33" />
        <rect x="12.8" y="10.66" width="3.5" height="3.33" />
      </g>
    </g>
  ),
  "lock.fill": (
    <g>
      <path d="M8 10.5V8a4 4 0 0 1 8 0v2.5" {...stroke} strokeWidth={2.2} />
      <rect x="5" y="10" width="14" height="11" rx="2.4" fill="currentColor" />
    </g>
  ),
  checkmark: <path d="m4.5 12.5 5 5 10-11" {...stroke} strokeWidth={2.8} />,
  "checkmark.circle.fill": (
    <g>
      <circle cx="12" cy="12" r="10" fill="currentColor" />
      <path d="m7.4 12.3 3.1 3.1 6.1-6.8" fill="none" stroke="var(--cb-bg-elevated, #fff)" strokeWidth="2.2" strokeLinecap="round" strokeLinejoin="round" />
    </g>
  ),
  circle: <circle cx="12" cy="12" r="9.5" {...stroke} strokeWidth={1.6} />,
  xmark: (
    <g {...stroke} strokeWidth={2.8}>
      <path d="M6 6l12 12M18 6 6 18" />
    </g>
  ),
  "hand.tap": (
    <g {...stroke} strokeWidth={1.6}>
      <path d="M10 13V5.5a1.6 1.6 0 0 1 3.2 0V11l4.3.9a2 2 0 0 1 1.6 2.2l-.6 4.4a3 3 0 0 1-3 2.5h-3.6a3 3 0 0 1-2.4-1.2L6 15.5a1.5 1.5 0 0 1 2.1-2.1Z" />
      <path d="M7.6 6.2a4.2 4.2 0 0 1 7.8 0" />
    </g>
  ),
  "ellipsis.circle": (
    <g>
      <circle cx="12" cy="12" r="9.5" {...stroke} strokeWidth={1.6} />
      <g fill="currentColor">
        <circle cx="7.6" cy="12" r="1.4" />
        <circle cx="12" cy="12" r="1.4" />
        <circle cx="16.4" cy="12" r="1.4" />
      </g>
    </g>
  ),
  "laurel.leading": (
    <g>
      <path d="M16.5 21.5C10 19.5 6.3 14.6 6.3 9.2c0-2.6.9-5 2.4-6.9" {...stroke} strokeWidth={1.4} />
      <g fill="currentColor">
        <ellipse cx="13.2" cy="19.6" rx="1.25" ry="2.5" transform="rotate(-35 13.2 19.6)" />
        <ellipse cx="10.4" cy="17.6" rx="1.25" ry="2.5" transform="rotate(-55 10.4 17.6)" />
        <ellipse cx="8.4" cy="14.8" rx="1.25" ry="2.5" transform="rotate(-70 8.4 14.8)" />
        <ellipse cx="7.4" cy="11.6" rx="1.25" ry="2.5" transform="rotate(-85 7.4 11.6)" />
        <ellipse cx="7.4" cy="8.4" rx="1.25" ry="2.5" transform="rotate(-100 7.4 8.4)" />
        <ellipse cx="8.4" cy="5.4" rx="1.25" ry="2.5" transform="rotate(-120 8.4 5.4)" />
        <ellipse cx="10.2" cy="3.0" rx="1.25" ry="2.5" transform="rotate(-140 10.2 3.0)" />
        <ellipse cx="12.6" cy="16.2" rx="1.25" ry="2.5" transform="rotate(20 12.6 16.2)" />
        <ellipse cx="10.8" cy="13.4" rx="1.25" ry="2.5" transform="rotate(10 10.8 13.4)" />
        <ellipse cx="10.0" cy="10.2" rx="1.25" ry="2.5" transform="rotate(0 10.0 10.2)" />
        <ellipse cx="10.3" cy="7.0" rx="1.25" ry="2.5" transform="rotate(-15 10.3 7.0)" />
      </g>
    </g>
  ),
  house: (
    <g {...stroke} strokeWidth={1.7}>
      <path d="M3.5 11 12 4l8.5 7" />
      <path d="M5.8 9.6V20h12.4V9.6" />
      <path d="M10 20v-5.5h4V20" />
    </g>
  ),
  power: (
    <g {...stroke} strokeWidth={2}>
      <path d="M12 3v8" />
      <path d="M7 6a8 8 0 1 0 10 0" />
    </g>
  ),
  "tray.and.arrow.down": (
    <g {...stroke} strokeWidth={1.7}>
      <path d="M12 3v10M8 9.5l4 4 4-4" />
      <path d="M3.5 14v4.5a2 2 0 0 0 2 2h13a2 2 0 0 0 2-2V14h-5a3.5 3.5 0 0 1-7 0Z" />
    </g>
  ),
  "sun.max.fill": (
    <g>
      <circle cx="12" cy="12" r="4.6" fill="currentColor" />
      <g {...stroke} strokeWidth={2}>
        <path d="M12 2v2.5M12 19.5V22M2 12h2.5M19.5 12H22M4.9 4.9l1.8 1.8M17.3 17.3l1.8 1.8M4.9 19.1l1.8-1.8M17.3 6.7l1.8-1.8" />
      </g>
    </g>
  ),
  "sunrise.fill": (
    <g>
      <path d="M6.5 16a5.5 5.5 0 0 1 11 0Z" fill="currentColor" />
      <g {...stroke} strokeWidth={1.9}>
        <path d="M2.5 19.5h19M12 3v4M9.5 5 12 2.8 14.5 5M3.5 13h2M18.5 13h2M5.6 7.6l1.4 1.4M18.4 7.6 17 9" />
      </g>
    </g>
  ),
  "sunset.fill": (
    <g>
      <path d="M6.5 16a5.5 5.5 0 0 1 11 0Z" fill="currentColor" />
      <g {...stroke} strokeWidth={1.9}>
        <path d="M2.5 19.5h19M12 2.5v4.2M9.5 4.6 12 6.8l2.5-2.2M3.5 13h2M18.5 13h2M5.6 7.6l1.4 1.4M18.4 7.6 17 9" />
      </g>
    </g>
  ),
  "moon.stars.fill": (
    <g fill="currentColor">
      <path d="M13.5 3.2A8.8 8.8 0 1 0 20.8 15 7 7 0 0 1 13.5 3.2Z" />
      <path d="m18 3 .7 1.6 1.6.7-1.6.7L18 7.6l-.7-1.6-1.6-.7 1.6-.7ZM21 9l.5 1 1 .5-1 .5-.5 1-.5-1-1-.5 1-.5Z" />
    </g>
  ),
  "arrow.up.right": arrow(0),
  "arrow.down.right": arrow(90),
  "arrow.down.left": arrow(180),
  "arrow.up.left": arrow(270),
  "chevron.down": <path d="m6 9 6 6 6-6" {...stroke} strokeWidth={2.4} />,
  "chevron.right": <path d="m9 6 6 6-6 6" {...stroke} strokeWidth={2.4} />,
  "hammer.fill": (
    <g fill="currentColor">
      <path d="M13.6 3.2 20.8 8l-2.3 2.6-2.4-1.6-8.9 10.2a2 2 0 0 1-3-2.7l8.9-10-1.2-1.6Z" />
    </g>
  ),
};

/** An SF Symbol from the app, as an inline SVG that takes the text color. */
export function Icon({ name, size = 17, color, label, style }: IconProps) {
  return (
    <svg
      viewBox="0 0 24 24"
      width={size}
      height={size}
      role={label ? "img" : undefined}
      aria-label={label}
      aria-hidden={label ? undefined : true}
      style={{ display: "inline-block", flex: "none", verticalAlign: "-0.15em", color, ...style }}
    >
      {glyphs[name]}
    </svg>
  );
}
