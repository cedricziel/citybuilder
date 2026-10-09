---
name: gamedata-review
description: Review a content-pack change for game plausibility before it merges, catching what validation cannot - dead-end goods, inert or unreachable buildings, out-of-band margins, odd tech gating, missing Swift behaviour or art. Use on any diff that touches Packages/CityCore/GameData/, including ones produced by the other gamedata skills.
---

# Review a content change

Read-only. Start from the semantic diff, not the YAML diff:

```bash
xcrun swift run --package-path Packages/GameDataGen gamedata-gen diff <base-ref>
```

Check, citing `<Kind> <id>` for each finding:

1. **Demand**: every new good has a consumer other than its own chain's next step being unused.
2. **Reachability**: every new building is unlocked by a researchable tech in a reachable age, and its placement can be satisfied.
3. **Economics**: output value ÷ input value per cycle, and value per tick against comparable existing buildings. Flag anything outside 1.1–2× without a stated reason.
4. **Gating**: techs that exist only to gate one building; prerequisite chains longer than today's longest.
5. **Behaviour**: each `effect: code` item has Swift behaviour in the same change or a named follow-up.
6. **Art**: catalog entries exist or are listed as follow-up.
7. **Determinism**: the change says the baselines were regenerated, or explains why not.

Report findings as BLOCKER / SHOULD-FIX / NIT with a concrete fix each, then a one-line verdict.
