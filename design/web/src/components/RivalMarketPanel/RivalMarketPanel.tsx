import { Glass } from "../Glass/Glass";
import "./RivalMarketPanel.css";

export interface RivalMarketPanelProps {
  /** "Wood — $5 — 12 available"; empty reads "Nothing for sale". */
  sells: string[];
  /** "Tools — $22 — wants 20"; empty reads "Buying nothing". */
  buys: string[];
  /** On its own glass card; in the inspector it sits under the port's lines. Default true. */
  framed?: boolean;
}

/** The Market section of a rival port's inspector: what the rival sells and buys, at what price. */
export function RivalMarketPanel({ sells, buys, framed = true }: RivalMarketPanelProps) {
  const body = (
    <div className="cb-rival-market">
      <div className="cb-rival-market__header">Market</div>
      <div className="cb-rival-market__sub">Sells</div>
      {(sells.length ? sells : ["Nothing for sale"]).map((line) => (
        <div key={line} className="cb-rival-market__line">
          {line}
        </div>
      ))}
      <div className="cb-rival-market__sub">Buys</div>
      {(buys.length ? buys : ["Buying nothing"]).map((line) => (
        <div key={line} className="cb-rival-market__line">
          {line}
        </div>
      ))}
    </div>
  );
  return framed ? (
    <Glass radius={10} padding={12} style={{ display: "inline-block" }}>
      {body}
    </Glass>
  ) : (
    body
  );
}
