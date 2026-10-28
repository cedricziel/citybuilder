import { Button } from "../Button/Button";
import { Glass } from "../Glass/Glass";
import { GoodIcon, type Good } from "../GoodIcon/GoodIcon";
import { Icon } from "../Icon/Icon";
import { ownerColours, type MinimapOwner } from "../Minimap/Minimap";
import "./OrdersBoard.css";

export interface OrderCard {
  id: number;
  /** "The Crown" or a rival town's name: "Ravenmoor". */
  issuer: string;
  /** Picks the issuer's dot: the crown's gold (`player`) or a rival's colour. */
  colour: MinimapOwner;
  /** "Timber for the fleet". */
  title: string;
  good: Good;
  /** "planks". */
  goodName: string;
  quantity: number;
  /** "by Autumn 1203". */
  deadline: string;
  /** "$540". */
  reward: string;
  /** "+2 favour". */
  favour: string;
  /** Accepted orders are outlined in the accent and show progress. */
  accepted?: boolean;
  /** A rival's order, filled by ship at its port. */
  byShip?: boolean;
  /** 0...1 of the quantity in the stores or delivered; accepted orders only. */
  progress?: number;
  /** "In stores 38 of 54", "Delivered 8 of 24 by ship" or "Offer ends with spring". */
  status: string;
  canAccept?: boolean;
  canSend?: boolean;
  canAbandon?: boolean;
}

export interface FavourRow {
  name: string;
  colour: MinimapOwner;
  value: number;
}

export interface OrdersBoardProps {
  cards: OrderCard[];
  /** The favour of the crown and of each rival, as pills under the title. */
  favour: FavourRow[];
  /** 340 on iPad and Mac, 300 on a phone, 520 on Apple TV. Default 340. */
  width?: number;
  height?: number;
  onClose?: () => void;
}

/**
 * The order board: a glass column on the trailing edge, below the menu
 * buttons and above the minimap, never covering the minimap or the build
 * rail. Accepted orders first, then offers by deadline, each a card with the
 * issuer, good, reward and the buttons its state allows. On a phone in
 * portrait it is a sheet instead.
 */
export function OrdersBoard({ cards, favour, width = 340, height, onClose }: OrdersBoardProps) {
  return (
    <Glass radius={12} padding="14px" className="cb-orders" style={{ width, height }}>
      <div className="cb-orders__head">
        <span className="cb-title3 cb-bold cb-orders__grow">Orders</span>
        <button type="button" className="cb-orders__close" aria-label="Close orders" onClick={onClose}>
          <Icon name="xmark" size={14} />
        </button>
      </div>
      <div className="cb-orders__pills" aria-label="Favour">
        {favour.map((row) => (
          <span key={row.name} className="cb-orders__pill">
            <span className="cb-orders__dot" style={{ background: ownerColours[row.colour] }} />
            <span className="cb-caption">{row.name.replace("The ", "")}</span>
            <span className="cb-caption cb-mono cb-semibold">{row.value}</span>
          </span>
        ))}
      </div>
      <div className="cb-orders__scroll">
        {cards.map((card) => (
          <OrderCardView key={card.id} card={card} />
        ))}
      </div>
    </Glass>
  );
}

function OrderCardView({ card }: { card: OrderCard }) {
  return (
    <div className={`cb-orders__card ${card.accepted ? "cb-orders__card--accepted" : ""}`}>
      <div className="cb-orders__row">
        <span className="cb-orders__dot" style={{ background: ownerColours[card.colour] }} />
        <span className="cb-caption cb-secondary">{card.issuer}</span>
        <span className="cb-orders__grow" />
        <span className="cb-caption cb-secondary">{card.deadline}</span>
      </div>
      <div className="cb-orders__row cb-orders__row--body">
        <GoodIcon good={card.good} size={32} />
        <div className="cb-orders__grow">
          <div className="cb-headline">{card.title}</div>
          <div className="cb-subheadline cb-mono">
            {card.quantity} {card.goodName}
          </div>
        </div>
        <div className="cb-orders__reward">
          <div className="cb-headline cb-mono">{card.reward}</div>
          <div className="cb-caption2 cb-secondary">{card.favour}</div>
        </div>
      </div>
      {card.accepted ? (
        <div className="cb-orders__progress" role="progressbar" aria-valuenow={Math.round((card.progress ?? 0) * 100)} aria-valuemax={100}>
          <div style={{ width: `${Math.min(100, (card.progress ?? 0) * 100)}%` }} />
        </div>
      ) : null}
      <div className="cb-caption cb-secondary">{card.status}</div>
      <div className="cb-orders__row">
        {card.accepted ? (
          <>
            {card.byShip ? (
              <span className="cb-caption cb-secondary">Unload at their port</span>
            ) : (
              <Button variant="borderedProminent" size="small" disabled={!card.canSend}>
                Send
              </Button>
            )}
            {card.canAbandon ? (
              <Button variant="borderless" size="small" role="destructive">
                Abandon
              </Button>
            ) : null}
          </>
        ) : (
          <>
            <Button variant="borderedProminent" size="small" disabled={!card.canAccept}>
              Accept
            </Button>
            <Button variant="bordered" size="small">
              Decline
            </Button>
          </>
        )}
      </div>
    </div>
  );
}
