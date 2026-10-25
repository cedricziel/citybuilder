import { OrdersChip, WorldBackdrop } from "@citybuilder/ui";

const OnMap = ({ children }: { children: React.ReactNode }) => (
  <WorldBackdrop width={420} height={90} zoom={2}>
    <div style={{ padding: 20, display: "flex", gap: 16, alignItems: "center" }}>{children}</div>
  </WorldBackdrop>
);

export const Capsule = () => (
  <OnMap>
    <OrdersChip accepted={0} />
    <OrdersChip accepted={1} offerWaiting />
    <OrdersChip accepted={2} />
  </OnMap>
);

export const Round = () => (
  <OnMap>
    <OrdersChip accepted={1} offerWaiting form="round" />
    <OrdersChip accepted={2} form="round" />
  </OnMap>
);
