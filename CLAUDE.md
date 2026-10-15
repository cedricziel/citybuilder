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
