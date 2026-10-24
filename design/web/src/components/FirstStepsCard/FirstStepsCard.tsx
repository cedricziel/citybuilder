import { Glass } from "../Glass/Glass";
import { Icon } from "../Icon/Icon";
import "./FirstStepsCard.css";

export interface FirstStep {
  /** "Build a farm", "Make planks: a lumberjack and a sawmill" ... */
  title: string;
  /** One caption line saying why: "Farms feed residents. Empty houses pay nothing." */
  reason: string;
  /** Met: a green filled check and a secondary title. */
  met?: boolean;
}

export interface FirstStepsLedger {
  /** Tax per collection, in dollars. */
  tax: number;
  /** Upkeep per collection, in dollars. */
  upkeep: number;
}

export interface FirstStepsCardProps {
  /** The five first-hour steps in order. Default: the game's steps, none met. */
  steps?: FirstStep[];
  /** Tax and upkeep per collection; the card shows the net, red while negative. */
  ledger: FirstStepsLedger;
  /**
   * The one-line capsule a narrow or short screen shows until it is tapped:
   * "First steps 2/5 · net -$16".
   */
  collapsed?: boolean;
  /** The card's close button. */
  onHide?: () => void;
  /** The capsule was tapped: show the card. */
  onExpand?: () => void;
}

/** The game's first-hour steps, none met. */
export const defaultFirstSteps: FirstStep[] = [
  { title: "Build a farm", reason: "Farms feed residents. Empty houses pay nothing." },
  { title: "Make planks: a lumberjack and a sawmill", reason: "A house needs 4 planks. The market sells them too." },
  { title: "Build 3 houses on a road", reason: "Fed residents move in and pay tax." },
  { title: "Earn more tax than upkeep", reason: "The net above decides your treasury." },
  { title: "Sell surplus at the market", reason: "Tap the town center when cash runs low." },
];

/** "$1,250", "-$16": the HUD's money format. */
export function formatMoney(amount: number): string {
  return `${amount < 0 ? "-" : ""}$${Math.abs(amount).toLocaleString("en-US")}`;
}

/**
 * The first-hour guide under the top-right HUD buttons: a 300px glass card
 * with the tax, upkeep and net ledger and the five steps, or on a narrow or
 * short screen a one-line capsule that expands when tapped.
 */
export function FirstStepsCard({ steps = defaultFirstSteps, ledger, collapsed = false, onHide, onExpand }: FirstStepsCardProps) {
  const net = ledger.tax - ledger.upkeep;
  const metCount = steps.filter((step) => step.met).length;
  if (collapsed) {
    return (
      <button type="button" className="cb-first-steps-capsule" onClick={onExpand}>
        <Glass shape="capsule" padding="0 12px" className="cb-first-steps-capsule__glass">
          <span className="cb-first-steps-capsule__title">
            First steps {metCount}/{steps.length}
          </span>
          <span className={`cb-first-steps-capsule__net ${net < 0 ? "cb-first-steps--negative" : ""}`}>· net {formatMoney(net)}</span>
        </Glass>
      </button>
    );
  }
  return (
    <Glass radius={12} padding="12px 14px" className="cb-first-steps">
      <div className="cb-first-steps__header">
        <span className="cb-headline">First steps</span>
        <span className="cb-first-steps__count">
          {metCount}/{steps.length}
        </span>
        <span style={{ flex: 1 }} />
        <button type="button" className="cb-first-steps__hide" aria-label="Hide first steps" onClick={onHide}>
          <Glass shape="circle" padding={8} style={{ display: "flex" }}>
            <Icon name="xmark" size={13} />
          </Glass>
        </button>
      </div>
      <div className="cb-first-steps__ledger">
        <Figure label="TAX" amount={ledger.tax} />
        <Figure label="UPKEEP" amount={ledger.upkeep} />
        <Figure label="NET" amount={net} negative={net < 0} />
      </div>
      <div className="cb-caption cb-secondary">Per collection, every 50 ticks.</div>
      {steps.map((step) => (
        <div key={step.title} className="cb-first-steps__step">
          <Icon
            name={step.met ? "checkmark.circle.fill" : "circle"}
            size={15}
            color={step.met ? "var(--cb-green)" : "var(--cb-secondary-label)"}
            style={{ verticalAlign: "-0.2em" }}
          />
          <div className="cb-first-steps__text">
            <div className={`cb-first-steps__title ${step.met ? "cb-secondary" : ""}`}>{step.title}</div>
            <div className="cb-caption cb-secondary">{step.reason}</div>
          </div>
        </div>
      ))}
    </Glass>
  );
}

function Figure({ label, amount, negative }: { label: string; amount: number; negative?: boolean }) {
  return (
    <div className="cb-first-steps__figure">
      <div className="cb-caption2 cb-secondary">{label}</div>
      <div className={`cb-first-steps__amount ${negative ? "cb-first-steps--negative" : ""}`}>{formatMoney(amount)}</div>
    </div>
  );
}
