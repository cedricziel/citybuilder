import { Glass } from "../Glass/Glass";
import { Icon } from "../Icon/Icon";
import { Button } from "../Button/Button";
import "./Coachmark.css";

export interface CoachmarkProps {
  /** The hint. Default "Long-press a tile to build" (the iOS first-run hint). */
  message?: string;
  /** Dismiss button title. Default "Got it". */
  action?: string;
  onDismiss?: () => void;
}

/** The first-run hint capsule at the bottom of the iOS game screen. */
export function Coachmark({ message = "Long-press a tile to build", action = "Got it", onDismiss }: CoachmarkProps) {
  return (
    <Glass shape="capsule" padding={12} className="cb-coachmark">
      <Icon name="hand.tap" size={20} />
      <span className="cb-coachmark__text">{message}</span>
      <Button variant="borderedProminent" size="small" onClick={onDismiss} style={{ borderRadius: 999, padding: "6px 14px", fontSize: 15 }}>
        {action}
      </Button>
    </Glass>
  );
}
