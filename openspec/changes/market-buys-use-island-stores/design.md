## Context

`town-market` sells from "the operational player goods buffers on the town center's island, in ascending entity ID order" but buys only into the town center's own 40-unit stockpile. A town that stores its planks in the town center cannot buy food once it is full, which is when food is most needed.

## Goals / Non-Goals

**Goals:**
- A purchase succeeds while any player store on the island has room.
- Buying and selling reach the same stores.

**Non-Goals:**
- Changing prices, limits or rival trades.
- Routing by road: the market works per island, as selling does.

## Decisions

### D1. Buy into the island's stores, not only report the failure

Issue #70 offers two options: deposit into the island's warehouses, or explain why a buy is blocked. The spec already settles which stores the market reaches: selling draws from every operational player goods buffer on the island. Buying into the same set removes the asymmetry and fixes the failure itself. Feedback alone would leave the player unable to buy food in exactly the situation the market is meant for. The panel already disables a Buy button when there is no room, so that feedback stays for the case where every store is full.

### D2. Town center first, then entity ID order

The town center fills first, so a town with room in it behaves exactly as before. The other buffers then fill in ascending entity ID order, the order selling drains them in. The order is deterministic and independent of `Dictionary` order.

### D3. The panel's room is the island's room

`MarketReach.freeSpace` becomes the sum of free space across the same buffers, so the Buy buttons enable exactly when a purchase can land.

## Risks / Trade-offs

- **Goods may land far from where they are needed.** A warehouse at the other end of the island receives the food; carriers then move it like any stored good. Selling has the same reach.

## Migration Plan

None: no saved state changes.
