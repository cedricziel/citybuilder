import { StandingsPanel } from "@citybuilder/ui";

export const ThreeTowns = () => (
  <div style={{ width: 480, height: 320, display: "flex" }}>
    <StandingsPanel
      rows={[
        { name: "You", colour: "player", population: "84", age: "Medieval", wealth: "$1,250", player: true },
        { name: "Ravenmoor", colour: "crimson", population: "62", age: "Medieval", wealth: "$940" },
        { name: "Saltmere", colour: "azure", population: "40", age: "Antiquity", wealth: "$610" },
        { name: "Thornwick", colour: "emerald", population: "18", age: "Antiquity", wealth: "$220" },
      ]}
    />
  </div>
);
