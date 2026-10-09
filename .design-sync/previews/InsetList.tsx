import { InsetList, ListRow } from "@citybuilder/ui";

export const Section = () => (
  <div style={{ background: "var(--cb-bg-grouped)", padding: "16px 0", width: 390 }}>
    <InsetList header="Audio">
      <ListRow>Music volume</ListRow>
      <ListRow>Effects volume</ListRow>
      <ListRow>Ambience</ListRow>
    </InsetList>
  </div>
);

export const ButtonRows = () => (
  <div style={{ background: "var(--cb-bg-grouped)", padding: "16px 0", width: 390 }}>
    <InsetList>
      <ListRow button>Masonry</ListRow>
      <ListRow button>Milling</ListRow>
      <ListRow button disabled>Printing Press</ListRow>
    </InsetList>
  </div>
);
