import { Icon, type IconName } from "@citybuilder/ui";

const names: IconName[] = [
  "pause.fill", "play.fill", "gearshape.fill", "gear", "book.fill", "flag.checkered", "lock.fill",
  "checkmark", "checkmark.circle.fill", "circle", "xmark", "hand.tap", "ellipsis.circle", "laurel.leading",
  "house", "power", "tray.and.arrow.down", "hammer.fill", "chevron.down", "chevron.right",
];
const time: IconName[] = ["sunrise.fill", "sun.max.fill", "sunset.fill", "moon.stars.fill"];
const arrows: IconName[] = ["arrow.up.left", "arrow.up.right", "arrow.down.left", "arrow.down.right"];

const Cell = ({ name, color }: { name: IconName; color?: string }) => (
  <div style={{ display: "flex", flexDirection: "column", alignItems: "center", gap: 6, width: 96 }}>
    <Icon name={name} size={26} color={color} />
    <span className="cb-caption2 cb-mono cb-secondary">{name}</span>
  </div>
);

export const Symbols = () => (
  <div style={{ display: "flex", flexWrap: "wrap", gap: 14, maxWidth: 560 }}>
    {names.map((name) => <Cell key={name} name={name} />)}
  </div>
);

export const TimeOfDay = () => (
  <div style={{ display: "flex", gap: 14 }}>
    {time.map((name) => <Cell key={name} name={name} color="var(--cb-orange)" />)}
  </div>
);

export const NudgeArrows = () => (
  <div style={{ display: "flex", gap: 14 }}>
    {arrows.map((name) => <Cell key={name} name={name} color="var(--cb-accent)" />)}
  </div>
);
