## Context

See proposal.md (Why). This change builds on facts that land with the changes it depends on:

- `add-culture-content`: `Culture.luxury` (beer, wine, tea, coffee), `BuildingKind.culture`, `PlacementRejection.wrongCulture` checked before the tech check, and the palette filter that hides other cultures' kinds. Merchants eat 1 luxury per 8 residents every 100 ticks.
- `add-age-signatures`: `FuelSpec` and `BuildingKind.fuel`, `Building.fuelled`, `runSignatureSystem` (fuel burns before production), `World.footprintDistance`, owner-scoped effects, range rings, `fuelRanOut`, and the monument tax multiplier.
- `add-rival-trade`: `Good.basePrice`. It may land before or after this change.

At the base commit, tax is summed over all houses each 50-tick interval, upkeep is summed over operational buildings each 50 ticks and then scaled by difficulty, and residents at citizens or above add 1 knowledge each every 100 ticks.

## Decisions

### D1 — Signatures are available from the start

Culture signature buildings need no tech. A culture should feel different from the first minutes, including in an Antiquity start, where Cultivation (Medieval) is out of reach. Each building works at its base rate without the luxury; the luxury chain doubles it once the player has one.

- **Alternative — unlock with Cultivation and require the luxury.** Rejected: Antiquity games would have no culture mechanic for a whole age, and a building that does nothing without a Medieval chain doesn't change early decisions.
- **Alternative — a new tech per culture.** Rejected: four techs, of which each player sees one, add research UI for no decision.

### D2 — Catalog entries

| Kind (raw value) | Culture | Footprint | Cost | Materials | Upkeep | Build ticks |
|---|---|---|---|---|---|---|
| mead hall (`mead-hall`) | Northern European | 3×3 | $180 | 6 wood, 2 planks | 1 | 35 |
| forum (`forum`) | Mediterranean | 3×3 | $220 | 2 wood, 6 planks | 2 | 40 |
| temple garden (`temple-garden`) | East Asian | 3×3 | $160 | 2 wood, 4 planks | 1 | 35 |
| caravanserai (`caravanserai`) | Middle Eastern | 3×3 | $200 | 4 wood, 4 planks | 2 | 40 |

All four are land-only, have a 16-unit stockpile and set `culture`, so a world of another culture rejects them with `wrongCulture` and hides them from the palette. Players may build as many as they like.

### D3 — Served luxury

Each kind's `fuel` is `FuelSpec(good: culture.luxury, amount: 1, intervalTicks: 100)`. Burns, supply (2 on hand) and `fuelRanOut` work as in `add-age-signatures`. In the UI a fuelled culture building is **served**. Several buildings of the same kind covering one target count once, at the best rate (served beats unserved).

- **Alternative — luxury required to work at all.** Rejected by D1.
- **Alternative — the luxury adds a different effect instead of doubling.** Rejected: "served doubles" is one rule the player learns once for all four cultures.

### D4 — Mead hall (Northern European): communal upkeep

Each upkeep interval, every operational non-house building of the same owner within 8 tiles of an operational mead hall, other than mead halls, pays half its catalog upkeep (rounded down), or nothing when a covering mead hall is served. Mead halls pay their own upkeep in full. Difficulty scaling then applies to the total as today.

Example on Normal: a sawmill (2) and a bakery (1) beside an unserved mead hall (1) cost 1 + 0 + 1 = 2 per interval; with beer served, 0 + 0 + 1 = 1.

The decision: cluster expensive buildings (steam engines, power plants, guild halls, warehouses) around mead halls, and spend beer there instead of on merchants.

- **Alternative — longhouse that raises house capacity.** Rejected: overlaps with the power plant from `add-age-signatures`.
- **Alternative — a guild-like production co-op.** Rejected: duplicates the Medieval guild hall.

### D5 — Forum (Mediterranean): market tax

Each tax interval, each house of the same owner within 8 tiles of an operational forum pays +1 per resident on top of its tier tax, or +2 when a covering forum is served. The bonus is part of the house's tax, so a completed monument's +10% applies to it.

Example: a merchant house of 8 residents near a forum pays 32 + 8 = 40; with wine served, 48; with a completed monument as well, 52.

The decision: where to put forums (dense quarters pay most), and whether wine goes to patricians or to the forum.

### D6 — Temple garden (East Asian): contemplation

Every 100 ticks, when resident knowledge is added, each house at citizens or above of the same owner within 6 tiles of an operational temple garden adds +1 knowledge per resident on top of the usual 1, or +2 when a covering temple garden is served. Peasant houses add nothing extra.

Example: a citizen house of 6 residents near a temple garden adds 6 + 6 = 12 knowledge per 100 ticks; with tea served, 18.

The decision: build temple gardens among the artisans and scholars, and trade tea between scholars and research.

- **Alternative — temple gardens raise satisfaction.** Rejected: the gallery already speeds up growth, and knowledge matches the East Asian tier names (Artisans, Scholars).

### D7 — Caravanserai (Middle Eastern): land trade

- **Export good:** `Building.exportGood: Good?`, set with `Command.setExport(EntityID, Good?)` on a caravanserai of the player. The command is ignored for other kinds and for coffee. A new caravanserai has none.
- **Supply:** supply carriers bring the export good to the caravanserai one unit at a time while its stock plus in-flight is below 8 and the goods buffers on its island (warehouses and town centers, not caravanserais) hold more than 10 of it in total. The reserve keeps a town from selling the food its houses need.
- **Caravans:** in `runSignatureSystem`, after fuel burns, on ticks whose count is a multiple of 100 (right after that tick's coffee burn), each operational caravanserai in ID order sends a caravan if it holds any goods other than coffee. The caravan takes up to 4 units, or 8 when served: the export good first, then any other goods in catalog order (left over after the export good changed). It credits units × `basePrice` to the owner's purse and emits `caravanSold(building:goods:revenue:)`. The goods leave the world.
- **Prices:** caravans pay full base price, more than rivals pay (75%) in `add-rival-trade`, but only a few units at a time.

Example: a caravanserai exporting bread sells 4 bread for $48 every 100 ticks; with coffee served, 8 for $96. Exporting tools with coffee served yields $240 per caravan.

The decision: what surplus to sell, and whether coffee goes to merchants or to caravans.

- **Alternative — a bazaar that raises tax nearby.** Rejected: too close to the forum.
- **Alternative — caravans walking to an off-map edge.** Deferred: walkers add path-finding and art for no change in the rule.

### D8 — Base prices

Caravans use `Good.basePrice`. This change adds the culture goods: hops, grapes, tea leaves and coffee cherries $3; beer, wine, tea and coffee $16. If `add-rival-trade` has not landed yet, this change adds the full table with the values listed in `add-rival-trade` (wood $4, planks $8, food $4, bread $12, grain $3, flour $6, ore $5, charcoal $5, iron $14, tools $30), and `add-rival-trade` reuses it.

### D9 — Rendering and UI

- **Range rings:** mead hall and forum 8 tiles, temple garden 6 tiles, using the ring and highlight from `add-age-signatures`. The caravanserai has no ring.
- **Animation:** the four buildings play their operational frames only while served; otherwise they show the idle sprite.
- **Inspector:**
  - mead hall: "Halves upkeep of 5 buildings", or "Serving beer: no upkeep for 5 buildings";
  - forum: "+1 tax per resident in 7 houses", or "Serving wine: +2 tax per resident in 7 houses";
  - temple garden: "+1 knowledge per resident from 24 residents", or "Serving tea: +2 knowledge per resident from 24 residents";
  - caravanserai: an export picker ("None" and every good except coffee, in catalog order), "Next caravan in 0:12", "Last caravan: 4 bread for $48", and "Serving coffee" or "No coffee".
- **Banner:** `fuelRanOut` reads "<Kind> is out of <fuel good>" for every fuelled kind ("Forum is out of wine"; the steam engine's text stays "Steam engine is out of charcoal").

### D10 — Art

Each building in its culture's `Style` in `buildings.py`, with an idle sprite, three construction stages and two operational frames:

- **Mead hall (Northern European):** long timber hall under a steep shingle roof with crossed carved gable boards, a smoke hole on the ridge, carved door posts, a bench and two barrels. Frames: smoke from the ridge and a warm lit doorway.
- **Forum (Mediterranean):** paved square with a colonnade under terracotta tiles on the two back sides, a statue on a plinth in the middle, a fountain and amphorae. Frames: striped awning stalls and a sparkling fountain.
- **Temple garden (East Asian):** raked gravel, a small shrine under a dark flared roof, a red gate, a stone lantern, a pond and a pine. Frames: incense smoke and lantern glow.
- **Caravanserai (Middle Eastern):** sandstone courtyard with an arched gate, a corner dome, parapets and a mashrabiya, a palm, sacks and a resting camel. Frames: an awning with coffee pots and brazier smoke.

### D11 — Saves

No migration. `Building` gains `exportGood: Good?`, read as nil when missing. `Command` gains `setExport(EntityID, Good?)`, which old saves don't contain. The new kinds and goods prices only appear in new saves. The save version is whatever it is when this lands (8, or 9 after `add-rival-towns`).

## Risks / Trade-offs

- **[Risk] Caravans of tools make too much money.** Tools at $30 × 8 every 100 ticks is $120 per 50-tick tax interval, about the tax of four full merchant houses. → Mitigation: selling 8 tools per 100 ticks needs five toolsmiths and the iron chain behind them, plus coffee; the 10-unit reserve and the 8-unit stock cap limit volume. The runtime check records caravan income over 6,000 ticks.
- **[Risk] Luxuries are short for both merchants and signatures.** → Accepted: that is the decision the change adds; each signature still works unserved.
- **[Risk] Forum and monument tax stack.** → Accepted: the monument takes an age of deliveries, and the forum only covers houses in range.
- **[Trade-off] The caravanserai has no range.** It doesn't need one; its decision is what to sell, not where to stand.

## Implementation notes

- **Last caravan (D7, D9, D11):** `Building.lastCaravan: CaravanSale?` (goods and revenue) records the last sale so the inspector's "Last caravan" line survives saves; it decodes as nil when missing, like `exportGood`.
- **Mead hall reach (D4):** the relief and the inspector count only buildings with catalog upkeep above 0 (houses, roads and other free buildings are not highlighted). Upkeep sums are unchanged by this.
- **Effects:** the three ranged signatures add `SignatureEffect.upkeepRelief`, `.marketTax` and `.contemplation` and the activation `.served` (always on, doubled while fuelled). Rates come from `World.cultureRate(of:on:from:)` through the `haveSameOwner` seam; tax, upkeep and knowledge are computed per house or building (`houseTax`, `upkeep(of:)`, `residentKnowledge`) so per-owner totals can sum them.
- **Owner seams still to wire when `add-rival-towns` lands:** `applySetExport` (player-only command) and `credit(_:toOwnerOf:)` (caravan revenue) in `World+Caravans.swift`.
- **Banner (D9):** a culture signature's `fuelRanOut` banner reads "Its effect halves until carriers bring more." instead of the age signatures' "Its effects stop".
- **Order of work:** the art (M4) landed before the catalog (M1) so that catalog entries and atlas sprites ship in the same commit as the new kinds.
