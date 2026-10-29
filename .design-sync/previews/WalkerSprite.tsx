import { WalkerSprite, type Facing } from "@citybuilder/ui";

const facings: Facing[] = ["se", "sw", "ne", "nw"];

const Row = ({ look }: { look: "worker" | "woman" | "watchman" }) => (
  <div style={{ display: "flex", gap: 16, alignItems: "flex-end" }}>
    {facings.map((facing) => (
      <div key={facing} style={{ display: "flex", flexDirection: "column", alignItems: "center", gap: 4 }}>
        <WalkerSprite look={look} facing={facing} scale={2} />
        <span className="cb-caption2 cb-mono cb-secondary">{facing}</span>
      </div>
    ))}
  </div>
);

export const Worker = () => <Row look="worker" />;
export const Woman = () => <Row look="woman" />;
export const Watchman = () => <Row look="watchman" />;
export const Standing = () => <WalkerSprite animate={false} scale={3} />;
