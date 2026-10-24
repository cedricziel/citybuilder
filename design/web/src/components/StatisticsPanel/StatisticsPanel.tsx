import type { ReactNode } from "react";
import { Sheet } from "../Sheet/Sheet";
import { SegmentedPicker } from "../SegmentedPicker/SegmentedPicker";
import { GoodIcon, type Good } from "../GoodIcon/GoodIcon";
import { Icon } from "../Icon/Icon";
import "./StatisticsPanel.css";

/** One line of numbers, a value per season, oldest first. */
export interface StatisticsSeries {
  name: string;
  values: number[];
  /** Any CSS colour. Default: the accent. */
  colour?: string;
}

export interface StatisticsGood {
  good: Good;
  name: string;
  /** Made minus used last season: "+3", "0". */
  net: string;
  /** Producers stopped now with this good stuck. */
  stopped?: number;
}

export interface StatisticsProducer {
  name: string;
  /** Fractions of last season, adding up to 1. */
  working: number;
  waiting: number;
  stuck: number;
  blocked: number;
}

export interface StatisticsGoodDetail {
  name: string;
  /** Last season's figures: made, used, sold, bought, stored. */
  figures: { label: string; value: number }[];
  made: number[];
  used: number[];
  stored: number[];
  /** Per season, the fraction (0 to 1) its producers were stopped with it stuck. */
  stuckShare: number[];
  producers: StatisticsProducer[];
}

export type StatisticsTab = "Goods" | "Money" | "People" | "Rivals";

export interface StatisticsPanelProps {
  /** The open tab. Default Goods. `Rivals` is offered only when `standings` has rivals. */
  tab?: StatisticsTab;
  /** The x axis: the year at the start of a year, "" between. One per season. */
  seasonLabels: string[];
  /** Goods tab: producers stopped now, across all goods. */
  stoppedNow?: number;
  goods?: StatisticsGood[];
  /** The selected good's name, and its detail. */
  selected?: string;
  detail?: StatisticsGoodDetail;
  /** Money tab: income draws above the axis, spending (negative) below. */
  income?: StatisticsSeries[];
  spending?: StatisticsSeries[];
  balance?: number[];
  /** People tab: residents per tier, stacked. */
  tiers?: StatisticsSeries[];
  /** Rivals tab: residents per town, "You" first, and the standings table. */
  towns?: StatisticsSeries[];
  standings?: { name: string; colour: string; residents: string; age: string; wealth: string }[];
  width?: number;
  height?: number;
  onDone?: () => void;
}

const chartWidth = 600;

const colours = {
  made: "var(--cb-accent)",
  used: "var(--cb-orange)",
  stuck: "var(--cb-red)",
  stored: "var(--cb-secondary-label)",
  working: "var(--cb-green)",
};

function rect(x: number, y: number, w: number, h: number) {
  return `M${x.toFixed(1)} ${y.toFixed(1)}h${w.toFixed(1)}v${h.toFixed(1)}h${(-w).toFixed(1)}z`;
}

/** The year labels under a chart, one cell per season. */
function Axis({ labels }: { labels: string[] }) {
  return (
    <div className="cb-stat__axis">
      {labels.map((label, index) => (
        <span key={index}>{label}</span>
      ))}
    </div>
  );
}

function Chart({ label, height, children }: { label: string; height: number; children: ReactNode }) {
  return (
    <svg className="cb-stat__chart" viewBox={`0 0 ${chartWidth} ${height}`} role="img" aria-label={label}>
      <path d={`M0 0.5H${chartWidth}M0 ${height / 2}H${chartWidth}M0 ${height - 0.5}H${chartWidth}`} className="cb-stat__grid" />
      {children}
    </svg>
  );
}

/** Bars side by side per season, one colour per series, drawn up from the axis. */
function GroupedBars({ series, height }: { series: { values: number[]; colour: string }[]; height: number }) {
  const count = Math.max(...series.map((s) => s.values.length), 1);
  const max = Math.max(...series.flatMap((s) => s.values), 1);
  const slot = chartWidth / count;
  const bar = Math.min(slot / (series.length + 1), 18);
  return (
    <>
      {series.map((s, index) => (
        <path
          key={index}
          fill={s.colour}
          d={s.values
            .map((value, season) => {
              const h = (value / max) * (height - 4);
              return h > 0 ? rect(slot * season + (slot - bar * series.length) / 2 + bar * index, height - h, bar - 1, h) : "";
            })
            .join("")}
        />
      ))}
    </>
  );
}

function Line({ values, colour, max, height }: { values: number[]; colour: string; max: number; height: number }) {
  const slot = chartWidth / Math.max(values.length, 1);
  const points = values.map((value, season) => `${(slot * (season + 0.5)).toFixed(1)} ${(height - (value / max) * (height - 4) - 2).toFixed(1)}`);
  return <path d={`M${points.join("L")}`} fill="none" stroke={colour} strokeWidth="2" />;
}

function Figure({ label, value }: { label: string; value: number }) {
  return (
    <div className="cb-stat__figure">
      <span className="cb-caption2 cb-secondary">{label.toUpperCase()}</span>
      <span className="cb-stat__value cb-mono">{value}</span>
    </div>
  );
}

function Key({ colour, children }: { colour: string; children: ReactNode }) {
  return (
    <span className="cb-stat__key">
      <i style={{ background: colour }} />
      {children}
    </span>
  );
}

function GoodsTab({ props }: { props: StatisticsPanelProps }) {
  const { goods = [], detail, selected, seasonLabels, stoppedNow = 0 } = props;
  const maxStored = Math.max(...(detail?.stored ?? [0]), 1);
  const stuck = detail?.stuckShare.some((share) => share > 0);
  return (
    <div className="cb-stat__goods">
      <div className="cb-stat__list">
        {stoppedNow > 0 ? (
          <div className="cb-stat__banner">
            <Icon name="xmark" size={12} />
            {stoppedNow} producers stopped: output stuck
          </div>
        ) : null}
        <div className="cb-inset-list">
          {goods.map((good) => (
            <div key={good.good} className={`cb-stat__row ${good.name === selected ? "cb-stat__row--on" : ""}`}>
              <GoodIcon good={good.good} size={24} />
              <span className="cb-stat__name">{good.name}</span>
              {good.stopped ? <span className="cb-stat__pill">{good.stopped} stopped</span> : null}
              <span className="cb-mono cb-secondary">{good.net}</span>
            </div>
          ))}
        </div>
      </div>
      {detail ? (
        <div className="cb-stat__detail">
          <div className="cb-title3 cb-bold">{detail.name}</div>
          <div className="cb-stat__figures">
            {detail.figures.map((figure) => (
              <Figure key={figure.label} label={figure.label} value={figure.value} />
            ))}
          </div>
          <div className="cb-footnote cb-semibold">Made and used per season</div>
          <Chart label={`${detail.name} made and used per season`} height={120}>
            <GroupedBars
              height={120}
              series={[
                { values: detail.made, colour: colours.made },
                { values: detail.used, colour: colours.used },
              ]}
            />
          </Chart>
          <div className="cb-footnote cb-semibold">In store at season end</div>
          <Chart label={`${detail.name} in store at season end`} height={80}>
            <Line values={detail.stored} colour={colours.stored} max={maxStored} height={80} />
          </Chart>
          {stuck ? (
            <>
              <div className="cb-footnote cb-semibold" style={{ color: colours.stuck }}>
                Stopped: output stuck
              </div>
              <Chart label="Share of each season its producers were stopped, output stuck" height={30}>
                <GroupedBars height={30} series={[{ values: detail.stuckShare, colour: colours.stuck }]} />
              </Chart>
            </>
          ) : null}
          <Axis labels={seasonLabels} />
          <div className="cb-stat__keys">
            <Key colour={colours.made}>Made</Key>
            <Key colour={colours.used}>Used</Key>
            <Key colour={colours.stored}>In store</Key>
          </div>
          {detail.producers.length > 0 ? (
            <div className="cb-stat__producers">
              <div className="cb-footnote cb-semibold">Who makes it, last season</div>
              {detail.producers.map((producer) => (
                <div key={producer.name}>
                  <div className="cb-subheadline">{producer.name}</div>
                  <div className="cb-stat__share">
                    <span style={{ flex: producer.working, background: colours.working }} />
                    <span style={{ flex: producer.waiting, background: colours.used }} />
                    <span style={{ flex: producer.stuck, background: colours.stuck }} />
                    <span style={{ flex: producer.blocked, background: colours.stored }} />
                  </div>
                </div>
              ))}
              <div className="cb-stat__keys">
                <Key colour={colours.working}>Working</Key>
                <Key colour={colours.used}>Waiting</Key>
                <Key colour={colours.stuck}>Stuck</Key>
                <Key colour={colours.stored}>Blocked</Key>
              </div>
            </div>
          ) : null}
        </div>
      ) : null}
    </div>
  );
}

const palette = ["var(--cb-accent)", "var(--cb-orange)", "var(--cb-green)", "var(--cb-red)"];
/** Money: income in blue and green above the axis, spending in orange and gray below. */
const incomeColours = [palette[0], palette[2]];
const spendingColours = [palette[1], "var(--cb-secondary-label)"];

function MoneyTab({ props }: { props: StatisticsPanelProps }) {
  const { income = [], spending = [], balance = [], seasonLabels } = props;
  const all = [...income, ...spending];
  const top = Math.max(...income.flatMap((s) => s.values), 1);
  const bottom = Math.max(...spending.flatMap((s) => s.values.map((v) => -v)), 1);
  const height = 140;
  const slot = chartWidth / Math.max(balance.length, 1);
  const zero = (top / (top + bottom)) * height;
  const stack = (group: StatisticsSeries[], sign: 1 | -1) =>
    group.map((series, index) => (
      <path
        key={series.name}
        fill={(sign === 1 ? incomeColours : spendingColours)[index % 2]}
        d={series.values
          .map((value, season) => {
            const below = group.slice(0, index).reduce((sum, s) => sum + Math.abs(s.values[season] ?? 0), 0);
            const h = (Math.abs(value) / (top + bottom)) * height;
            const offset = (below / (top + bottom)) * height;
            return h > 0 ? rect(slot * season + 6, sign === 1 ? zero - offset - h : zero + offset, slot - 12, h) : "";
          })
          .join("")}
      />
    ));
  const maxBalance = Math.max(...balance, 1);
  return (
    <div className="cb-stat__page">
      <div className="cb-footnote cb-semibold">Income and upkeep per season</div>
      <Chart label="Income above the line, spending below, per season" height={height}>
        {stack(income, 1)}
        {stack(spending, -1)}
        <path d={`M0 ${zero}H${chartWidth}`} className="cb-stat__zero" />
      </Chart>
      <div className="cb-stat__keys">
        {all.map((series, index) => (
          <Key key={series.name} colour={index >= income.length ? spendingColours[(index - income.length) % 2] : incomeColours[index % 2]}>
            {series.name}
          </Key>
        ))}
      </div>
      <div className="cb-footnote cb-semibold">Balance at season end</div>
      <Chart label="Balance at the end of each season" height={70}>
        <Line values={balance} colour={colours.stored} max={maxBalance} height={70} />
      </Chart>
      <Axis labels={seasonLabels} />
    </div>
  );
}

function StackedAreas({ series, height }: { series: StatisticsSeries[]; height: number }) {
  const count = Math.max(...series.map((s) => s.values.length), 1);
  const slot = chartWidth / count;
  const max = Math.max(...Array.from({ length: count }, (_, season) => series.reduce((sum, s) => sum + (s.values[season] ?? 0), 0)), 1);
  const y = (value: number) => (height - (value / max) * (height - 4) - 2).toFixed(1);
  return (
    <>
      {series.map((s, index) => {
        const base = (season: number) => series.slice(0, index).reduce((sum, t) => sum + (t.values[season] ?? 0), 0);
        const seasons = Array.from({ length: count }, (_, season) => season);
        const top = seasons.map((season) => `${(slot * (season + 0.5)).toFixed(1)} ${y(base(season) + (s.values[season] ?? 0))}`);
        const bottom = [...seasons].reverse().map((season) => `${(slot * (season + 0.5)).toFixed(1)} ${y(base(season))}`);
        return <path key={s.name} d={`M${top.join("L")}L${bottom.join("L")}z`} fill={s.colour ?? palette[index % palette.length]} />;
      })}
    </>
  );
}

function PeopleTab({ props }: { props: StatisticsPanelProps }) {
  const { tiers = [], seasonLabels } = props;
  return (
    <div className="cb-stat__page">
      <div className="cb-footnote cb-semibold">Residents by tier, season end</div>
      <Chart label="Residents by house tier at the end of each season" height={180}>
        <StackedAreas series={tiers} height={180} />
      </Chart>
      <Axis labels={seasonLabels} />
      <div className="cb-stat__keys">
        {tiers.map((tier, index) => (
          <Key key={tier.name} colour={tier.colour ?? palette[index % palette.length]}>
            {tier.name}
          </Key>
        ))}
      </div>
    </div>
  );
}

function RivalsTab({ props }: { props: StatisticsPanelProps }) {
  const { towns = [], standings = [], seasonLabels } = props;
  const max = Math.max(...towns.flatMap((s) => s.values), 1);
  return (
    <div className="cb-stat__page">
      <div className="cb-footnote cb-semibold">Residents by town, season end</div>
      <Chart label="Residents of your town and each rival at the end of each season" height={150}>
        {towns.map((town, index) => (
          <Line key={town.name} values={town.values} colour={town.colour ?? palette[index % palette.length]} max={max} height={150} />
        ))}
      </Chart>
      <Axis labels={seasonLabels} />
      <div className="cb-inset-list">
        {standings.map((row) => (
          <div key={row.name} className={`cb-stat__row ${row.name === "You" ? "cb-stat__row--you" : ""}`}>
            <span className="cb-stat__dot" style={{ background: row.colour }} />
            <span className="cb-stat__name">{row.name}</span>
            <span className="cb-mono">{row.residents}</span>
            <span className="cb-secondary">{row.age}</span>
            <span className="cb-mono">{row.wealth}</span>
          </div>
        ))}
      </div>
    </div>
  );
}

/**
 * The Statistics sheet, opened from the chart button in the HUD's menu
 * buttons: a segmented control with Goods, Money, People and Rivals over the
 * last 40 seasons. Goods lists every good with its net and a red "stopped"
 * pill while a producer of it is stopped because its output has nowhere to
 * go; the detail shows made against used, the store level and that strip.
 */
export function StatisticsPanel(props: StatisticsPanelProps) {
  const { tab = "Goods", standings, width, height, onDone } = props;
  const tabs: StatisticsTab[] = standings && standings.length > 1 ? ["Goods", "Money", "People", "Rivals"] : ["Goods", "Money", "People"];
  return (
    <Sheet title="Statistics" width={width} height={height} onDone={onDone}>
      <div className="cb-stat">
        <SegmentedPicker options={tabs} selected={tab} label="Statistics view" />
        {tab === "Goods" ? <GoodsTab props={props} /> : null}
        {tab === "Money" ? <MoneyTab props={props} /> : null}
        {tab === "People" ? <PeopleTab props={props} /> : null}
        {tab === "Rivals" ? <RivalsTab props={props} /> : null}
      </div>
    </Sheet>
  );
}
