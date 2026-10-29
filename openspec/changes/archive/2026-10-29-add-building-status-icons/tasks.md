## 1. Art

- [x] 1.1 `scripts/art/status_icons.py`: pictograms, and "short" and "stuck" icons for every good, built on `goods_icons`; pytest for names and well-formed SVG
- [x] 1.2 Catalog brief `status-icons.md` (`source = "svg"`); render into `Kit.atlas` at @1x and @2x; add the stems to `TextureFiltering.kitRenderedStems`

## 2. Rendering

- [x] 2.1 Tests first: translate the scenarios of "Buildings show a status icon while something is wrong" and the changed "Road-access marker" scenario into failing CityRender2D tests; confirm red
- [x] 2.2 `StatusIcons.swift`: the issue-to-icon mapping, the reconcile pass (one node per building, zoom scale, bob, Reduce Motion) and the icon hit test; remove the `SKShapeNode` no-road disc
- [x] 2.3 Tap on an icon selects its building when no tool is armed

## 3. Design system

- [x] 3.1 `design/web`: a `StatusIcon` component with the same states, sizes and Reduce Motion rule

## 4. Verification

- [x] 4.1 In-game before and after shots on the Mac at zoom 1 and 0.5, by day and at night, in the PR's `## Design`
