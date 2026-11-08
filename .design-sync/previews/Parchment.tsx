import { Parchment, WorldBackdrop } from "@citybuilder/ui";

export const Panel = () => (
  <WorldBackdrop width={360} height={180} zoom={2}>
    <div style={{ position: "absolute", left: 24, top: 24, right: 24 }}>
      <Parchment padding={12}>
        <div className="cb-parchment-title" style={{ fontSize: 17 }}>Bakery</div>
        <div style={{ fontSize: 12, opacity: 0.8 }}>Working · on the road</div>
      </Parchment>
    </div>
  </WorldBackdrop>
);
