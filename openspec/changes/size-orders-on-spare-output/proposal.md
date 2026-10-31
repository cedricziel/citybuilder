## Why

Orders are sized from what the town *made* of a good (#379). Since the market hub, a sawmill takes logs straight from the lumberjack huts, so in a town with a sawmill almost no wood reaches a store, yet the crown still asks for wood sized on everything the huts cut. In the solvency sweep most failed orders had 0 wood in stock from acceptance to deadline. The offer looks fillable when it isn't. PR #378 moves the PlayerBot's order kit to judge orders on spare output; the game should offer on the same basis.

## What Changes

- **BREAKING (balance):** an order's size follows the good's *spare* output instead of its gross output: made plus bought, less what production (recipe inputs and fuel) and construction used and what the market sold, summed over the last up to 4 closed seasons. What the houses used still counts, since the player can divert it to an order; this is the trade-off the orders ask for.
- A season that used more than it made counts against the others in the window. When the window's spare output is 0 or below, the template is not eligible: the crown (or rival) offers another good, or nothing. There is no minimum offer for a good the town uses up, because an order the stores never see the goods for cannot be filled. The existing rule that a template below its minimum quantity is not eligible is unchanged.
- The rule is the one function every order uses, so crown orders, rival orders and the festival's two town orders all move to spare output. For bread and the luxuries, which only houses consume, spare equals made unless the market sold some.

## Capabilities

### New Capabilities
- (none)

### Modified Capabilities
- `orders`: "Order size follows the town's output" uses spare output.
- `seasonal-events`: "The town asks for a festival" sizes its orders on spare output.

## Impact

- **CityCore**: `GoodFlow.spare`, `World.recentOrderUnits(for:)`.
- **Determinism**: the `DeterminismFixture` issues orders, so its output changes; the macOS/Linux compare is unaffected.
- **Archive order**: the deltas modify requirements that `add-orders` and `add-event-counterplay` add, so this change archives after both.
- No new player-visible text.
