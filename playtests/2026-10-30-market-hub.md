# Market hub (0.2.10): ship, but look at the population swings first (2026-10-30)

Newcomer pass (iPhone 17), builder pass (iPad Pro 11-inch), and a short UI audit (iPhone SE) of the market hub, marketplace, porters, and the new Campaigns screens. Screenshots are in `2026-10-30-market-newcomer/`, `2026-10-30-market-builder/` and `2026-10-30-market-ui-audit/`.

## Setup

- Build: `9244bfb7` (origin/main), Debug, iOS simulator only.
- Newcomer: iPhone 17, portrait. Regular New Game from the title screen, defaults (seed 0, Northern European, Medieval), no launch flags, First steps guide on. About 25 real minutes, Summer 1200 to Spring 1204.
- Builder: iPad Pro 11-inch (M5), portrait. Title screen and Campaigns by hand, then `-uiTestSeedLived -uiTestStartGame` to watch an established town (test funds, so the economy is not judged). About 15 real minutes.
- UI audit: iPhone SE (3rd generation, created for this run and deleted afterwards), Campaigns at default and AXXXL text size, light and dark; marketplace placement with `-uiTestSeedTown -uiTestStartGame`.
- Not covered: tvOS (no tvOS build; the host was saturated and a second full build was not worth the slot), Mac, landscape, Pro Max.
- Host: a PlayerBot sweep and other agents' test runs kept the load average between 30 and 630. The first launch took about 12 minutes to reach the title screen. Taps often landed 5 to 20 seconds late, and some were lost, so several "tap did nothing" moments were retried before being counted.

## What works

- **Marketplace in the build menu.** Town drawer, "Marketplace $150", on iPhone 17, iPad and SE (`newcomer/05`, `ui-audit/se-05`). Arming it shows "Marketplace · $150" with wood "6/3" and planks "5/4" in the strip (`newcomer/06`), which matches the brief: $150, wood 3, planks 4. It places, charges $150, and shows the usual no-road badge until a road is laid (SE).
- **Town center trading.** "Details" on the town center lists buy and sell prices per good with Buy 1, Buy 5, Sell 1 and Sell 5. Buy 5 planks worked: "Planks — buy $12 (10 left)" changed to "(5 left)" (`newcomer/09`).
- **Workers and carts are visible.** In the lived town, people with handcarts move between the plaza and the producers, and people walk the plaza (`builder/03`, `builder/04`). Houses show a food bubble with a red "!" when they want food; the bubbles come and go.
- **No-road messaging** stays clear. The banner "Gather & Craft buildings work only when connected to a road" and the red badge explain an unconnected farm (`newcomer/07`).
- **Campaigns.** Title screen → Campaigns → map icon, "Campaigns", "The first campaign is on its way. Chapters will appear here with a coming update." Close returns to the title on every device. It looks deliberate:
  - iPhone 17 and SE: a full sheet (`newcomer/02`, `ui-audit/se-02`).
  - iPad: a centred form sheet, not a split view. With no chapters this reads fine (`builder/01`).
  - SE at AXXXL in dark mode, the text wraps and stays readable (the map icon drops off the screen) (`ui-audit/se-03`, `se-04`).

## Findings, by severity

### Bug

1. **Population swings wildly with nothing on screen to explain it.** In the lived seed, POP. read 14 at load, then 7, 12, 9, 11, 6, 13, 8, 4, 8, 9, 7, 11, 13, 9, 9, 10, all within about three real minutes, with no banner or hint (`builder/06` is a strip of eight HUD frames eight seconds apart). In the real newcomer game the first house turned two-storey (red roof, POP. 6), dropped back to one storey with POP. 4, rose again, and dropped again (`newcomer/10`, `newcomer/12`). The house bubbles show food wanted while it happens (`builder/02`, `builder/05`). The likely cause is the house-stock change: residents leave or downgrade when the house stock runs dry between porter trips. I did not compare against 0.2.9, so I cannot say for sure that this is new. To a player, the town looks like it is breaking down.
   _Steps:_ launch `-uiTestSeedLived -uiTestStartGame` on any device and watch POP. for one minute at 1x.

### UX

2. **The first hour never mentions markets.** The First steps card only says "sell surplus at the town center (Details → Market)" (`newcomer/04`). Nothing tells a new player that houses need a market in reach, or that a marketplace exists to serve far houses. I never saw "No market in reach". Every house I could place sat inside the town center's reach, and the far house I tried could not be placed (item 3). The status exists in the inspector code, but I could not trigger it by play in either session.
3. **An orange tick refuses without a reason.** When the ghost overlaps a road, the plaza or another building, the confirm tick turns orange and a tap does nothing. No text, no haptic, no hint ("overlaps a road" or similar) (`newcomer/12`, `ui-audit/se-07`). As a newcomer I took it as "warning, but allowed" and pressed it four times. With a far-off house it looks like the market rule blocks it, which is misleading. Not new in 0.2.10, but the market hub makes players place houses farther out, so they hit it more.
4. **Neither the house nor the town center inspector shows market information.** The house callout shows State, Road, Residents and names, but no house stock and no line naming the market that serves it (`newcomer/10`). The town center callout shows nothing about reach, porters or houses served (`newcomer/09`). The builder brief asked for house-stock information in the inspector; there is none.
5. **I could not tell porters from producers' carters.** I saw people with handcarts and walkers near the plaza (`builder/03`, `04`), but I could not pick out a basket or tell full from empty at any zoom I tried on iPad. At iPhone zoom they are a few pixels tall.
6. **Houses flip their tier look visibly.** Tied to item 1: the red two-storey house swaps back to the brown one-storey model and back again while you watch (`newcomer/10` vs `newcomer/12`).

### Polish

7. **The expanded town center callout slides under the season pill** on iPhone 17. "Town" is hidden and only "Ctr." shows (`newcomer/09`).
8. **The placement HUD clips at the screen edge.** On iPhone 17, near the right edge, the confirm and right-hand nudge buttons are half off screen (`newcomer/11`). On the SE, near the left edge, the left nudge arrows are half off screen (`ui-audit/se-06`).
9. **The title-screen diorama shows a red no-road badge** above one house, on iPhone, iPad and SE (`newcomer/01`, `builder/00`, `ui-audit/se-01`). The `-uiTestSeedTown` town has the same badge. The showcase town advertises a broken building.
10. **Roads are hard to see on autumn and winter ground.** Freshly laid roads nearly vanish on autumn grass and on snow (`newcomer/07`, `builder/05`). I laid several single tiles a step short of the plaza because I could not see the gap.
11. **The town center callout stays open** when you tap the map; only "Less" closes it.

## Not exercised

- A second marketplace serving houses beyond the town center's reach, and the "No market in reach" status: not reached by play (see items 2 and 3).
- Rival marketplaces (no rival in these games).
- Tier advancement to citizens and merchants: the lived town never held a stable tier (item 1).
- Apple TV focus on Campaigns and its Close, Mac, landscape layouts, and Pro Max.

## Call for 0.2.10

**Ship.** Nothing crashed, the marketplace builds with the right cost, town center trading works, and Campaigns is a clean, deliberate empty state on every device I opened. Item 1 is the one thing I would check before tagging: run the lived seed on 0.2.9 for a minute. If POP. there is stable, the swings are a market hub regression. Then I would hold the release for a fix, because a population counter that halves and doubles every few seconds looks like a broken game. If 0.2.9 swings the same way, ship and file items 1 to 4 as the next market follow-ups.
