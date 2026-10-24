# Citybuilder

## Visual changes go through Claude Design

A significant visual change must be designed on a Claude Design canvas before any code or art for it is implemented. "Significant" means any of these:

- a new or redrawn art family: buildings, terrain, units, ships or effects
- a change to the overall look: lighting, palette, materials or rendering style
- a new screen or panel, or a HUD layout change
- a new animation or motion style

Bug fixes, pixel nudges, tolerance tweaks and changes that keep the approved design don't need a canvas.

1. **Start the canvas.** Call the Artifact tool with `action: "quickstart"` and `intent: "design"`, then create the canvas from the Design type it returns.
2. **Show the current state.** Put the "before" on the canvas: an in-game shot, or the current UI.
3. **Add options.** Lay out 2–3 options next to it, as mockups or real renders. Mockups are made in-repo, never with generative image models.
4. **Recommend.** Say which option you recommend, and why.
5. **Get approval.** Send the canvas link to the orchestrator (`main`), which decides and passes the link to the owner. Wait for the go-ahead on the option before you implement it. The owner can comment on the canvas at any time; a comment overrides the decision.
6. **Link the PR.** Put the canvas link in the PR body under `## Design`, together with the in-game before and after shots of what was built.

A PR with a significant visual change and no `## Design` canvas link doesn't merge.

## Visual changes keep `design/web` and the design system in step

The "Citybuilder" design system (https://claude.ai/artifact/4jaGCEE3CUjDaC6G1LKb2T) is built from `design/web`, the React recreation of the HUD and the art. `design/web` is the source of truth; the design system is a published copy of it.

1. **Update `design/web` in the same PR.** A visual change to an art family, a HUD element, a sheet, a banner or an icon isn't done until its `design/web` counterpart exists or matches the game: the component in `design/web/src/components/`, its preview in `.design-sync/previews/`, and the sprite or icon source in `design/web/scripts/gen-sprites.mjs`. Keep `npm run typecheck` and `npm run build` in `design/web` green.
2. **Say so in the PR.** Put a `## Design system` section in the PR body naming the `design/web` components you added or changed, or "none" with the reason.
3. **Republish after merge.** Once the PR is on `main`, republish the changed components to the design system from `design/web`, one component at a time, updating the artifact in place.
