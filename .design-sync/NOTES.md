# Claude Design sync notes

- The app is SwiftUI, so Claude Design can't use its views directly. `design/web/` (`@citybuilder/ui`) is a
  hand-made React recreation of `Packages/CityUI` (HUD, palette, inspector, banners, sheets, title screen), and the
  sync runs the package shape against it. It drifts unless someone updates it: a CityUI change does not reach
  Claude Design until the matching component in `design/web/src/components/` changes. The user chose this
  reimplementation knowingly (first sync, 2026-10-09).
- Build: `cd design/web && npm ci && npm run build`. `scripts/gen-sprites.mjs` first inlines the pixel art from
  `Resources/{Icons,Buildings,Terrain}.atlas` as data URIs into `src/generated/` (gitignored), skipping culture/era
  variants and animation frames; then esbuild bundles `src/index.ts` + CSS, and tsc emits the `.d.ts`. Then from the
  repo root: `node .ds-sync/package-build.mjs --config .design-sync/config.json --node-modules design/web/node_modules --entry design/web/dist/index.js --out ./ds-bundle`.
- Groups come from `design/web/docs/<Name>.md` (only `category` frontmatter: Foundations, Art, HUD, Sheets, Screens).
  `.prompt.md` is synthesized from JSDoc and props, so JSDoc on components and props is the design agent's documentation.
- `guidelinesGlob` points at a path that doesn't exist on purpose: the default (`docs/*.md`) would ship the category stubs.
- `PaletteButton`, `HUDButtonCluster` and `ListRow` are excluded from cards (`componentSrcMap: null`); they stay in the
  bundle and show inside the BuildPalette, HUDButton and InsetList cards.
- SF Symbols can't ship, so `Icon` draws the symbols the app uses as hand-made inline SVG. Add a glyph there when
  CityUI starts using a new `systemImage`. `book.fill` at 20px once read as a second pause button; keep the open-book
  shape distinct from `pause.fill`.
- Fonts are the system stacks (SF via `-apple-system`, `ui-monospace`, `ui-serif`). Don't name "New York" or
  "SF Pro" in a stack: validate reports `[FONT_MISSING]` for named families that don't ship.
- Playwright must match the cached chromium: `~/Library/Caches/ms-playwright/chromium-1243` -> `playwright@1.63.0` in `.ds-sync/`.
- HUD previews sit on a `WorldBackdrop` strip so the thin material reads as it does in the game; on a white card the
  glass is invisible. Most cards use `cardMode: "column"` because the map strips are wider than a grid cell.
- `GameScreen` `placing` puts a ghost on map tile (4,4) of the default town and draws the world with `focusY` 0.62 so
  the nudge arrows don't cover the armed caption. A custom `world.map`/`buildings` must leave (4,4)-(5,5) free.
- npm here blocks install scripts (`allow-scripts`); esbuild still works through its platform package.

## Known render warns

- None at the first sync.

## Re-sync risks

- Everything in `design/web` is a copy of SwiftUI layout constants (paddings, radii, fonts) read from
  `Packages/CityUI/Sources/CityUI/*.swift` on 2026-10-09. Re-read `HUDFrameView`, `BuildPaletteView`, `InspectorView`,
  `SessionBanner`, `PauseMenuView`, `TitleScreenView`, `NewGameDialogView`, `TouchPlacementViews` and
  `CityUI.swift` (`rootContent`) for changes before a re-sync.
- Content strings (ages, cultures, scenarios, palette order, tech names) are inlined from CityCore and will go stale
  as the game grows: `NewGameDialog.tsx`, `defaultPaletteTools` in `BuildPalette.tsx`, and the previews.
- Colors are Apple system values (`tokens.css`), not read from an asset catalog: the app has no custom accent.
  If one is added to `Apps/*/Assets.xcassets`, update `--cb-accent`.
- Grading was absolute (no reference render): nobody compared the cards against simulator screenshots side by side.
