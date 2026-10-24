import { StatusIcon, statusLabel, type StatusIssue } from "@citybuilder/ui";

const issues: StatusIssue[] = [
  { good: "flour", state: "short" },
  { good: "bread", state: "short" },
  { good: "planks", state: "stuck" },
  "storage-full",
  "no-road",
  "no-route",
  "no-trees",
  "no-room-to-plant",
];

export const AllStates = () => (
  <div style={{ display: "flex", flexWrap: "wrap", gap: 12, maxWidth: 560, padding: 12, background: "#5a7432" }}>
    {issues.map((issue) => (
      <div key={statusLabel(issue)} style={{ display: "flex", flexDirection: "column", alignItems: "center", gap: 4, width: 96 }}>
        <StatusIcon issue={issue} size={40} bob={false} />
        <span className="cb-caption2" style={{ color: "#fff", textAlign: "center" }}>{statusLabel(issue)}</span>
      </div>
    ))}
  </div>
);

export const PlatformSizes = () => (
  <div style={{ display: "flex", alignItems: "flex-end", gap: 16, padding: 12, background: "#5a7432" }}>
    <StatusIcon issue={{ good: "bread", state: "short" }} size="mac" />
    <StatusIcon issue={{ good: "bread", state: "short" }} size="touch" />
    <StatusIcon issue={{ good: "bread", state: "short" }} size="tv" />
    <StatusIcon issue={{ good: "bread", state: "short" }} size="mac" zoom={0.5} />
  </div>
);
