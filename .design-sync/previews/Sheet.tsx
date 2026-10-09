import { Sheet, InsetList, ListRow } from "@citybuilder/ui";

export const WithTitle = () => (
  <Sheet title="Statistics" width={390} height={300}>
    <InsetList>
      <ListRow>Population 84</ListRow>
      <ListRow>Houses 14</ListRow>
      <ListRow>Warehouses 2</ListRow>
    </InsetList>
  </Sheet>
);

export const PlainDialog = () => (
  <Sheet doneLabel={null} background="plain" width={390} height={180}>
    <div style={{ padding: "8px 24px" }}>
      <div className="cb-title cb-bold">Save failed</div>
      <div className="cb-body cb-secondary" style={{ marginTop: 8 }}>
        The file could not be written. Free some space and try again.
      </div>
    </div>
  </Sheet>
);
