# Citybuilder: how to build with this library

These components recreate Citybuilder, an Apple-only isometric city builder (iPhone, iPad, Mac) written in SwiftUI. The look is stock Apple: SF system font, system colors with a blue accent, translucent thin-material panels floating over a pixel-art world map, iOS sheets with large titles. The one custom surface is the parchment `SessionBanner` (cream card, brown ink, 2px leather edge) for in-world announcements. Don't invent other brand colors.

## Setup

Wrap every screen in `CityProvider`. It sets the `--cb-*` tokens and the system font. Without it, text falls back to the browser default font and every token is undefined.

```jsx
const { CityProvider, GameScreen, GoalsPanel } = window.CitybuilderUI;

<CityProvider theme="light">   {/* theme="dark" for dark appearance */}
  <GameScreen width={1180} height={820}
    sheet={<GoalsPanel goals={[{ text: "Residents 32/40", met: false }, { text: "Bread 20/20", met: true }]} />} />
</CityProvider>
```

`background="plain" | "grouped"` paints a page background. Omit it when the content is a `WorldBackdrop`.

## Building screens

- **Gameplay**: start from `GameScreen`. It stacks the HUD exactly as the app does: `HUDFrame` with `HUDButtonCluster` at the top, `BuildPalette`, `RejectionBanner`, `SessionBanner`, `HintCapsule` and `CostBreakdown` while a tool is armed, `Inspector` at the bottom left, and on touch the `Coachmark` and `PlacementHUD`. Pass a sheet (`GoalsPanel`, `ResearchPanel`, `PauseMenu`, `ScenarioWon`, `TileMenu`) through `sheet`. Sizes: iPhone landscape 844x390, iPad 1180x820, Mac window 1280x800 (`device="mac"` drops the touch-only pieces).
- **Custom in-game views**: put your own layout in `WorldBackdrop` children. Every floating panel goes on `Glass` (radius 12 for panels, 10 for the inspector, 8 for strips, 6 for chips, `capsule`, `circle`). Never use an opaque card over the map.
- **Menus**: `TitleScreen` (serif wordmark, 280px button column), `NewGameDialog`, and plain iOS sheets built from `Sheet` + `InsetList` + `ListRow`.
- **Art**: `GoodIcon` (18 goods: `wood`, `planks`, `food`, `grain`, `flour`, `bread`, `ore`, `charcoal`, `iron`, `tools`, `hops`, `beer`, `grapes`, `wine`, `tea-leaves`, `tea`, `coffee-cherries`, `coffee`), `BuildingSprite` (`house`, `house-tier2`, `house-tier3`, `warehouse`, `town-center`, `lumberjack-hut`, `sawmill`, `farm`, `windmill`, `bakery`, `mine`, `monument`, `road`, ...), `TerrainTile`. Pixel art: never smooth or recolor it.
- **Controls**: `Button` (`borderedProminent` for the single main action, `bordered`, `borderless`, `plain`; `role="destructive"`), `SegmentedPicker`, `MenuPicker`, `Icon` (SF Symbol names such as `pause.fill`, `book.fill`, `flag.checkered`, `lock.fill`, `checkmark.circle.fill`, `hand.tap`).

## Styling idiom

No utility framework. Use components for everything they cover, and plain flex/grid with inline styles for glue. Every color is a token, so dark mode keeps working:

| Purpose | Tokens |
|---|---|
| Text | `--cb-label`, `--cb-secondary-label`, `--cb-tertiary-label` |
| Surfaces | `--cb-bg`, `--cb-bg-grouped`, `--cb-bg-elevated`, `--cb-material` (glass), `--cb-scrim` |
| Lines and fills | `--cb-separator`, `--cb-fill`, `--cb-fill-secondary` |
| System colors | `--cb-accent` (blue), `--cb-red`, `--cb-orange`, `--cb-green` |
| Parchment | `--cb-parchment`, `--cb-parchment-ink`, `--cb-parchment-edge` |
| Radii | `--cb-radius-xs` 6, `--cb-radius-sm` 8, `--cb-radius-md` 10, `--cb-radius-lg` 12, `--cb-radius-sheet` 14, `--cb-radius-pill` |
| Fonts | `--cb-font` (SF), `--cb-font-mono` (numbers, palette, inspector), `--cb-font-serif` (title wordmark only) |

Type classes follow the iOS ramp: `cb-large-title`, `cb-title`, `cb-title2`, `cb-title3`, `cb-headline`, `cb-body`, `cb-callout`, `cb-subheadline`, `cb-footnote`, `cb-caption`, `cb-caption2`, plus `cb-mono`, `cb-serif`, `cb-semibold`, `cb-bold`, `cb-secondary`, and `cb-pixel` on any `<img>` of game art. Game numbers (money, counts, costs, ticks) are always monospaced.

## Where the truth lives

Read `styles.css` and its imports (all tokens and component CSS) before styling. Each component's `.prompt.md` and `.d.ts` list its props. Realistic content to reuse: dates like "Spring 1203" or "Winter 498 BC", money "$1,250", "Pop. 84", palette names "House", "Lumberjack", "Grain Farm", "Toolsmith", and costs as "House — $120".
