import { ResearchPanel } from "@citybuilder/ui";

export const Medieval = () => (
  <ResearchPanel
    width={420}
    height={560}
    techs={[
      { name: "Masonry", state: "researched", cost: 20, unlocks: "Warehouse" },
      { name: "Milling", state: "inProgress", cost: 40, progress: 26, unlocks: "Windmill, Bakery", requires: "Masonry" },
      { name: "Brewing", state: "available", cost: 50, unlocks: "Hop Garden, Brewery" },
      { name: "Metallurgy", state: "available", cost: 60, unlocks: "Smelter, Toolsmith", requires: "Masonry" },
      { name: "Feudal Order", state: "locked", cost: 80, unlocks: "Guild Hall", requires: "Metallurgy, 30 citizens" },
      { name: "Printing Press", state: "locked", cost: 120, unlocks: "The Renaissance age", requires: "Feudal Order, 40 merchants" },
    ]}
  />
);
