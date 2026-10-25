import { StatisticsPanel } from "@citybuilder/ui";

const seasonLabels = ["1202", "", "", "", "1203", "", "", "", "1204", "", "", ""];

const bread = {
  name: "Bread",
  figures: [
    { label: "Made", value: 22 },
    { label: "Used", value: 22 },
    { label: "Sold", value: 0 },
    { label: "Bought", value: 0 },
    { label: "Stored", value: 80 },
  ],
  made: [0, 0, 6, 10, 14, 18, 22, 28, 34, 36, 30, 22],
  used: [0, 0, 2, 4, 7, 10, 13, 16, 18, 20, 22, 22],
  stored: [0, 0, 4, 10, 17, 25, 34, 47, 63, 80, 80, 80],
  storeCap: 80,
  stuckShare: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0.1, 0.55, 0.83],
  producers: [{ name: "Bakery", working: 0.17, waiting: 0.12, stuck: 0.71, blocked: 0 }],
};

const goods = [
  { good: "wood" as const, name: "Wood", net: "+0" },
  { good: "planks" as const, name: "Planks", net: "+0" },
  { good: "food" as const, name: "Food", net: "+2" },
  { good: "flour" as const, name: "Flour", net: "+3", stopped: 1 },
  { good: "bread" as const, name: "Bread", net: "0", stopped: 2 },
  { good: "iron" as const, name: "Iron", net: "+1" },
];

const shell = (children: React.ReactNode) => <div style={{ width: 880, height: 640, display: "flex" }}>{children}</div>;

export const GoodsStopped = () =>
  shell(<StatisticsPanel width={880} seasonLabels={seasonLabels} stoppedNow={3} goods={goods} selected="Bread" detail={bread} />);

export const Money = () =>
  shell(
    <StatisticsPanel
      width={880}
      tab="Money"
      seasonLabels={seasonLabels}
      income={[
        { name: "Tax", values: [0, 8, 16, 24, 30, 38, 44, 52, 60, 68, 72, 78] },
        { name: "Trade", values: [0, 0, 0, 0, 10, 0, 20, 0, 30, 0, 16, 0] },
      ]}
      spending={[{ name: "Upkeep", values: [-4, -8, -12, -16, -22, -28, -32, -38, -44, -50, -54, -58] }]}
      balance={[1000, 1010, 1050, 1100, 1170, 1240, 1330, 1450, 1560, 1700, 1810, 1950]}
    />,
  );

export const People = () =>
  shell(
    <StatisticsPanel
      width={880}
      tab="People"
      seasonLabels={seasonLabels}
      tiers={[
        { name: "Peasants", colour: "#9ec5fe", values: [4, 8, 12, 16, 20, 24, 26, 28, 28, 28, 28, 28] },
        { name: "Citizens", colour: "#0a64d6", values: [0, 0, 0, 0, 2, 6, 10, 16, 22, 26, 30, 34] },
        { name: "Merchants", colour: "#b45309", values: [0, 0, 0, 0, 0, 0, 0, 0, 2, 6, 10, 16] },
      ]}
    />,
  );

export const Rivals = () =>
  shell(
    <StatisticsPanel
      width={880}
      tab="Rivals"
      seasonLabels={seasonLabels}
      towns={[
        { name: "You", colour: "#D4A017", values: [4, 8, 12, 16, 22, 30, 36, 44, 52, 60, 68, 78] },
        { name: "Ravenmoor", colour: "#B03A2E", values: [6, 10, 14, 18, 22, 24, 26, 28, 28, 30, 30, 30] },
        { name: "Saltwick", colour: "#2E6DB4", values: [5, 8, 10, 12, 14, 16, 18, 20, 22, 24, 26, 28] },
      ]}
      standings={[
        { name: "You", colour: "#D4A017", residents: "78", age: "Medieval", wealth: "$1,950" },
        { name: "Ravenmoor", colour: "#B03A2E", residents: "30", age: "Medieval", wealth: "$1,120" },
        { name: "Saltwick", colour: "#2E6DB4", residents: "28", age: "Medieval", wealth: "$840" },
      ]}
    />,
  );
