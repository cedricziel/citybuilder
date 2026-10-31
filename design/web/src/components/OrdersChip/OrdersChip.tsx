import { Glass } from "../Glass/Glass";
import { Icon } from "../Icon/Icon";
import "./OrdersChip.css";

export interface OrdersChipProps {
  /** Orders accepted now, of the 2 that can be open. */
  accepted: number;
  /** An offer waits on the board: a red dot marks the chip. */
  offerWaiting?: boolean;
  /** `capsule` ("Orders 1/2") on iPad and Mac; `round` with the count as a badge on a phone and on Apple TV, whose top bar has no room for the word. Default `capsule`. */
  form?: "capsule" | "round";
  onClick?: () => void;
}

/**
 * The HUD's entry to the order board: the count of accepted orders over the
 * open limit, and a dot while an offer waits. Sits at the left of the menu
 * buttons.
 */
export function OrdersChip({ accepted, offerWaiting, form = "capsule", onClick }: OrdersChipProps) {
  const label = `Orders ${accepted} of 2${offerWaiting ? ", an offer waits" : ""}`;
  const dot = offerWaiting ? <span className="cb-orders-chip__dot" aria-hidden="true" /> : null;
  if (form === "round") {
    return (
      <button type="button" className="cb-orders-chip cb-orders-chip--round" aria-label={label} onClick={onClick}>
        <Glass shape="circle" style={{ width: 38, height: 38 }} className="cb-orders-chip__face">
          <Icon name="scroll.fill" size={19} />
        </Glass>
        {dot}
        <span className="cb-orders-chip__badge cb-caption2 cb-mono cb-semibold">{accepted}</span>
      </button>
    );
  }
  return (
    <button type="button" className="cb-orders-chip" aria-label={label} onClick={onClick}>
      <Glass shape="capsule" padding="6px 12px" className="cb-orders-chip__face">
        <Icon name="scroll.fill" size={14} />
        <span className="cb-subheadline cb-semibold">Orders</span>
        <span className="cb-subheadline cb-mono">{accepted}/2</span>
      </Glass>
      {dot}
    </button>
  );
}
