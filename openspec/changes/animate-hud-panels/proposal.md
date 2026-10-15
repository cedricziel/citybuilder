## Why

In game, the build drawer, the inspector callout, the route bar and the market's other goods appear and disappear in a single frame. The jump is abrupt next to the drifting title screen and the animated banners, and it makes it hard to see where a panel came from.

## What Changes

- The build drawer slides out of the build rail: from the left on iPad, Mac and Apple TV, and up from the dock on iPhone.
- The inspector callout rises a few points into place and fades in. When the player inspects another building, the callout glides to it.
- The route bar slides up from the bottom when route mode starts.
- The market's other goods fade in when the player shows them.
- With Reduce Motion on, every one of these panels fades instead, in 0.15 seconds, with no movement.

## Capabilities

### New Capabilities
- (none)

### Modified Capabilities
- `platform-shells`: a new requirement, "HUD panels animate in and out".

## Impact

- **CityUI:**
  - New `PanelMotion`, which picks a panel's transition and animation from its edge and Reduce Motion.
  - `BuildDrawerView`, `CityRootView.inspectorCallout`, `hudLayer`'s route bar and `TownMarketView` use it.
- **CityCore, CityRender2D:** no change.
- **Performance:** transitions animate only opacity and offset, so the HUD draws no extra layers. The inspector's per-tick text updates are not animated, because only the selection drives the animation.
