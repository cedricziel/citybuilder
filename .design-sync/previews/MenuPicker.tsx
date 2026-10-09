import { MenuPicker } from "@citybuilder/ui";

export const Regular = () => (
  <MenuPicker options={["Antiquity", "Medieval", "Renaissance", "Industrial", "Modern"]} selected="Medieval" />
);

export const WithLabel = () => (
  <MenuPicker label="Culture" options={["Northern European", "Mediterranean", "East Asian", "Middle Eastern"]} selected="Mediterranean" />
);

export const Small = () => (
  <MenuPicker label="Export" size="small" options={["None", "Bread", "Tools", "Wine"]} selected="Wine" />
);
