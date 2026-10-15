---
name: art-direction-canvas
description: Explore and compare visual directions for citybuilder's isometric world on a Claude Design canvas, with art Claude draws (SVG) or authors as 3D code, never image generation. Use when asked to try a new look, compare art styles, mock up a town scene, or judge whether the game "feels alive" or "looks like Anno" (issue #84). Not for producing final atlas sprites (use iso-sprite-authoring).
---

# Art direction on a canvas

Round 1 (issue #84) result: **pre-rendered 3D buildings on painterly 2D terrain**.
The owner values **realism** ("what I like about Anno is the realism"), so
judge realism first. Canvas: "Citybuilder art direction".

## Scene recipe (reuse it, so rounds compare)

`scenes/*.svg` hold Round 1's scenes. Each file = one `<defs>` symbol library
(`house`, `houseB`, `townhall`, `sawmill`, `hut`, `forester`, `tree`, `pine`,
`grove`, `walker`, `cart`, `boat`, `strip`) + an **identical placement block**.
A new direction = a new symbol library; copy the placement block unchanged.

- Island on a 16×16 grid, tile 64×32, `point(c,r) = (640+32(c-r), 120+16(c+r))`;
  crop `viewBox="180 70 1040 560"` (1:1 game scale).
- Houses (2×2) at top corners (640,248) (704,280) (544,296) (608,328) (736,392)
  (800,424) (960,376) (864,456); town hall 3×3 at (864,328); sawmill (576,376);
  lumberjack (448,280); forester (704,184). Main road r=6, cross road c=9 to a
  pier at c=9 r=12–14.5, fields c12–15 r9–11, forest c≤3.
- Paint back to front by footprint bottom corner (c+r+w+h). Walkers on a road
  go after the row behind them.
- Light from screen upper-left; shadows fall toward +c (screen right).

## Workflow

1. Write each direction as a standalone `.svg` in the scratchpad and render it
   with `rsvg-convert` (`-z 2` for display). Look at the PNG before it goes
   on the canvas. Judging means looking.
2. Upload PNGs as canvas assets and make each artboard a thin HTML wrapper:
   title, image, then three cells: Works / Weak / Verdict. Uploaded SVGs lose
   `<style>`, so render to PNG instead.
3. Always include: a baseline artboard with the real atlas PNGs at 3× pixelated,
   a comparison table, and a sprite-scale proof (see iso-sprite-authoring).
4. Compare on: realism, warm light, terrain blending, density and scale, visible
   life, **consistency across 40+ buildings**, **cost per new asset**, and
   **animation** (smoke, mills, construction stages). Keep at most one
   stylized direction, as a contrast.

## What Round 1 showed

- Pixel (world.md palette, 1 px outlines) beats the current atlas at once, but
  reads as Anno 1602 with flat materials. It is the fallback, not the target.
- Painterly SVG gives the best terrain and atmosphere; its buildings stay
  illustrations and drift when hand-shaded one by one.
- SceneKit pre-renders read as built and real. Mixed with SVG buildings, the
  mismatch is obvious, so every building must come from one route.
- Clean vector reads as Townscaper; low-poly reads as a toy.

## Pitfalls hit

- feTurbulence water with high alpha looks like clouds. Use stretched
  `baseFrequency="0.004 0.08"` and alpha ≤ 0.3.
- Dashed foam strokes read as bricks. Use two solid blurred strokes.
- rsvg only loads `<image href>` files beside the SVG (no parent dirs).
- A diorama island larger than its board pokes out. Clip land to the board.
- Bugs such as a floating chimney hide at scene scale. Check sprites at 3×.
- The canvas artboard files get reformatted by a hook. It is harmless, but keep
  the `support.js` line and the single-quoted `data-props` intact.
