import { OrdersBoard, WorldBackdrop, type OrderCard } from "@citybuilder/ui";

const crownTimber: OrderCard = {
  id: 1,
  issuer: "The Crown",
  colour: "player",
  title: "Timber for the fleet",
  good: "planks",
  goodName: "planks",
  quantity: 54,
  deadline: "by Autumn 1203",
  reward: "$540",
  favour: "+2 favour",
  accepted: true,
  progress: 38 / 54,
  status: "In stores 38 of 54",
  canSend: false,
  canAbandon: true,
};

const ravenmoorBread: OrderCard = {
  id: 2,
  issuer: "Ravenmoor",
  colour: "crimson",
  title: "Bread for Ravenmoor",
  good: "bread",
  goodName: "bread",
  quantity: 24,
  deadline: "by Summer 1203",
  reward: "$120",
  favour: "+2 favour",
  accepted: true,
  byShip: true,
  progress: 8 / 24,
  status: "Delivered 8 of 24 by ship",
};

const crownTools: OrderCard = {
  id: 3,
  issuer: "The Crown",
  colour: "player",
  title: "Tools for the works",
  good: "tools",
  goodName: "tools",
  quantity: 12,
  deadline: "by Winter 1203",
  reward: "$486",
  favour: "+2 favour",
  status: "Offer ends with spring",
  canAccept: false,
};

const favour = [
  { name: "The Crown", colour: "player" as const, value: 7 },
  { name: "Ravenmoor", colour: "crimson" as const, value: 3 },
  { name: "Saltmere", colour: "azure" as const, value: 0 },
];

const OnMap = ({ children }: { children: React.ReactNode }) => (
  <WorldBackdrop width={420} height={560} zoom={2}>
    <div style={{ padding: 16, display: "flex", justifyContent: "flex-end" }}>{children}</div>
  </WorldBackdrop>
);

export const AtTheLimit = () => (
  <OnMap>
    <OrdersBoard cards={[crownTimber, ravenmoorBread, crownTools]} favour={favour} height={520} />
  </OnMap>
);

export const OfferWaiting = () => (
  <OnMap>
    <OrdersBoard
      cards={[{ ...crownTools, canAccept: true }]}
      favour={favour}
      height={300}
    />
  </OnMap>
);

const festivalBread: OrderCard = {
  id: 4,
  issuer: "Your town",
  colour: "player",
  title: "Bread for the festival",
  good: "bread",
  goodName: "bread",
  quantity: 12,
  deadline: "by Spring 1204",
  reward: "Festival",
  favour: "No favour at stake",
  festival: true,
  status: "Offer ends with spring",
  canAccept: true,
};

const festivalBeer: OrderCard = {
  ...festivalBread,
  id: 5,
  title: "Beer for the festival",
  good: "beer",
  goodName: "beer",
  quantity: 8,
};

export const FestivalBesideTheLimit = () => (
  <OnMap>
    <OrdersBoard cards={[crownTimber, ravenmoorBread, festivalBread, festivalBeer]} favour={favour} height={560} />
  </OnMap>
);
