## Purpose

Shows every player-visible string in the player's language, English or German, from String Catalogs, while the simulation core stays language-free and the pack YAML stays the single source for content.

## ADDED Requirements

### Requirement: Player-visible text comes from the catalogs in the player's language

Every string the game shows to the player (views, banners, inspector lines, menus, chips, accessibility labels, pack content) SHALL come from a String Catalog entry. The game SHALL show German when German is the first of the player's preferred languages that the game supports, and English otherwise. English SHALL be the development language and the fallback. The game SHALL NOT offer its own language switch; the system and per-app language settings choose.

#### Scenario: German locale shows German text
- **WHEN** the UI resolves the pause menu's resume button with German as the preferred language
- **THEN** the label reads "Weiter"

#### Scenario: An unsupported language falls back to English
- **WHEN** the UI resolves the pause menu's resume button with French, then Spanish, as the preferred languages
- **THEN** the label reads "Resume"

#### Scenario: English keeps today's text
- **WHEN** the UI resolves the bountiful-harvest history banner with English as the preferred language
- **THEN** its title reads "Bountiful harvest" and its text reads "The fields gave more than expected: 8 food reaches the stores."

#### Scenario: Tests resolve text in a pinned language
- **WHEN** a test resolves any catalog string without naming a language
- **THEN** it gets the English text, whatever the language of the machine running the test

### Requirement: The simulation core emits keys and arguments, not sentences

The simulation core SHALL describe player-facing facts (history events, scenario goals, seasons, dates, difficulty, seasonal-event banners, order texts, pack names) as a stable key plus typed arguments, and SHALL NOT build or return natural-language sentences. Amounts inside a message SHALL be arguments taken from the same constants the simulation uses. Adding keys SHALL NOT change any simulation state, save field, RNG draw or tick order.

#### Scenario: A history event carries its key and amount
- **WHEN** the core reports a bountiful harvest
- **THEN** the event's message has the key `history.bountifulHarvest.text` and a `food` argument equal to the food the harvest adds

#### Scenario: A date before year 1 reads per locale
- **WHEN** the UI formats spring of year 0 in English and in German
- **THEN** it reads "Spring 1 BC" in English and "Frühling 1 v. Chr." in German

#### Scenario: Keyed messages leave the simulation unchanged
- **WHEN** the determinism fixture runs its seeded world after this change
- **THEN** its post-tick world JSON equals the JSON recorded before this change

### Requirement: Pack text has keys generated from the YAML

Every player-visible field of a pack item (names, units, blurbs, seasonal-event banner titles and texts, order titles and texts, campaign and chapter texts) SHALL have a catalog key derived from the item's kind, its id and the field name. The game-data generator SHALL write these keys with their English values into the generated catalog, so the YAML stays the single source of the English text. German values in the generated catalog SHALL survive regeneration. When an English value changes in the YAML, the generator SHALL mark that key's German value as needing review. `gamedata-check` SHALL fail when the committed generated catalog differs from what the packs produce.

#### Scenario: A pack name gets a derived key
- **WHEN** the generator runs over the core pack
- **THEN** the generated catalog has the key `building.grainFarm.name` with the English value "Grain Farm"

#### Scenario: German values survive regeneration
- **WHEN** the generated catalog has a reviewed German value for `good.wood.name` and the generator runs again over unchanged packs
- **THEN** the German value and its reviewed state are unchanged

#### Scenario: Changing English text marks German for review
- **WHEN** the English name of a good changes in its pack and the generator runs
- **THEN** that key's German value is kept and marked as needing review

#### Scenario: A removed pack item drops its keys
- **WHEN** an item is removed from its pack and the generator runs
- **THEN** the generated catalog no longer has that item's keys

#### Scenario: Pack placeholders are named
- **WHEN** a pack text contains a placeholder such as `{building}`
- **THEN** the generated English value keeps the named placeholder, and the UI fills it after looking the text up in the player's language

### Requirement: Arguments are formatted for the player's language

Counts SHALL choose the catalog's plural form for the player's language. Numbers and money SHALL use the player's locale for digit grouping. A noun passed into a sentence SHALL be the noun's own localized text. German sentences SHALL NOT put an article or an adjective directly before a noun placeholder, because the noun's gender and case are not known; they SHALL phrase around it instead.

#### Scenario: Counts pick the plural form
- **WHEN** the UI formats a fire's toll of 1 and of 3 buildings in English and German
- **THEN** it reads "1 building", "3 buildings", "1 Gebäude" and "3 Gebäude"

#### Scenario: Numbers use the locale's grouping
- **WHEN** the UI formats a balance of 1500 in German
- **THEN** the digits read "1.500"

#### Scenario: A noun placeholder is filled with the localized noun
- **WHEN** the fire banner names a burning grain farm in German
- **THEN** the text contains the German name of the grain farm and no English word

### Requirement: A completeness check guards the catalogs

A check SHALL run in CI and locally and SHALL fail when any catalog key lacks a German value, when a German value is not marked reviewed, when a German value's format specifiers or named placeholders differ from the English value's, when source code names a key that no catalog has, when a German value puts an article directly before a noun placeholder, when a German value uses a word the glossary lists as avoided, or when a German value addresses the player formally.

#### Scenario: A missing German value fails the check
- **WHEN** a catalog key has an English value and no German value
- **THEN** the check fails and names the key

#### Scenario: A German value needing review fails the check
- **WHEN** a German value is marked as needing review
- **THEN** the check fails and names the key

#### Scenario: A placeholder mismatch fails the check
- **WHEN** the English value has `%lld` and `{date}` and the German value has only `%lld`
- **THEN** the check fails and names the key and the missing placeholder

#### Scenario: An unknown key in code fails the check
- **WHEN** source code looks up a key that no catalog has
- **THEN** the check fails and names the file, the line and the key

#### Scenario: An article before a noun placeholder fails the check
- **WHEN** a German value contains "Eine {building}"
- **THEN** the check fails and names the key

#### Scenario: An avoided glossary word fails the check
- **WHEN** a German value uses "Bestellung" where the glossary says "Auftrag"
- **THEN** the check fails and names the key and the glossary term

#### Scenario: Formal address fails the check
- **WHEN** a German value contains "Sie können"
- **THEN** the check fails and names the key

#### Scenario: Complete catalogs pass the check
- **WHEN** every key has a reviewed German value with matching placeholders and every looked-up key exists
- **THEN** the check passes

### Requirement: A pseudo-locale exposes long and bypassed strings

A pseudo-locale SHALL transform every string that goes through the catalogs: it SHALL replace letters with accented look-alikes, pad the text to at least 140% of its length, and wrap it in brackets, keeping format specifiers and named placeholders intact. A launch argument SHALL turn it on in the app for playtests, and tests SHALL be able to resolve text in it. Labels listed as tight SHALL fit their width budget in German and in the pseudo-locale, measured at the font the HUD draws them in.

#### Scenario: The pseudo-locale lengthens and marks a string
- **WHEN** the pause menu's resume button resolves in the pseudo-locale
- **THEN** the label starts with "[", ends with "]", contains no unaccented letter of "Resume", and is at least 1.4 times as long as "Resume"

#### Scenario: The pseudo-locale keeps placeholders
- **WHEN** a text with `%lld` and `{date}` resolves in the pseudo-locale
- **THEN** both placeholders appear unchanged and fill as in English

#### Scenario: Tight labels fit in German
- **WHEN** every label listed as tight is measured in German at its HUD font
- **THEN** each fits its width budget

#### Scenario: Tight labels fit in the pseudo-locale
- **WHEN** every label listed as tight is measured in the pseudo-locale at its HUD font
- **THEN** each fits its width budget, or the label is listed as a known pseudo overflow with an issue number

### Requirement: Rival town names are translated for display only

A rival town's stored name SHALL stay as it is in the world and the save. The UI SHALL show the catalog's translation of a stored name that the game itself generated, and SHALL show any other stored name unchanged.

#### Scenario: A generated rival name shows in German
- **WHEN** a rival named "Bay of Knives" is shown with German as the preferred language
- **THEN** the UI shows "Messerbucht" and the world still stores "Bay of Knives"

#### Scenario: An unknown rival name shows as stored
- **WHEN** a rival whose stored name has no catalog entry is shown in German
- **THEN** the UI shows the stored name

### Requirement: German text follows the glossary and tone guide

German strings SHALL address the player with du and imperatives ("Baue", "Wähle"), SHALL use the glossary's word for every glossary term, and SHALL keep a plain, period-appropriate game tone: short sentences, native words over anglicisms, no gender-colon or asterisk forms. The glossary SHALL list, for each term, the German word and the words to avoid. The check matches avoided words case-sensitively as whole words; a term with no avoided word (—) is enforced by review only.

| English | German | Avoid |
|---|---|---|
| market | Markt | Basar |
| warehouse | Lagerhaus | Depot, Warenhaus |
| storage, stock | Lager, Vorrat | Inventar |
| granary | Kornspeicher | Silo |
| carrier, porter | Träger | Kurier, Transporteur |
| handcart | Handkarren | Schubkarre |
| goods | Waren | Güter, Items |
| order | Auftrag | Bestellung, Order |
| order board | Auftragstafel | Bestellbrett |
| crown | Krone | — |
| rival town | Nachbarstadt | Gegner, Konkurrent |
| caravan | Karawane | Konvoi |
| blight | Fäule | Mehltau |
| crop failure | Missernte | Ernteausfall |
| fever | Fieber | Seuche |
| festival | Fest | Festival, Party |
| fire watch | Feuerwache | Feuerwehr |
| ruins | Ruinen | Trümmerhaufen |
| clear ruins | Ruinen räumen | Ruinen löschen |
| fuel | Brennstoff | Treibstoff |
| physician | Medicus | Doktor |
| residents | Einwohner | Bewohner |
| peasants / citizens / merchants | Bauern / Bürger / Kaufleute | — |
| town center | Rathaus | Stadtzentrum |
| tax | Steuern | Abgaben |
| upkeep | Unterhalt | Wartung |
| treasury | Stadtkasse | Konto |
| bankrupt | bankrott | pleite |
| research | Forschung | — |
| knowledge | Wissen | Kenntnisse |
| age (era) | Zeitalter | Ära, Epoche |
| Antiquity / Medieval / Renaissance / Industrial / Modern | Antike / Mittelalter / Renaissance / Industriezeitalter / Moderne | — |
| spring / summer / autumn / winter | Frühling / Sommer / Herbst / Winter | Frühjahr |
| BC | v. Chr. | BC, vor Christus |
| road | Straße | — |
| harbour, port | Hafen | Port |
| shipyard | Werft | Schiffswerft |
| demolish | abreißen | — |
| resume | Weiter | Fortsetzen |
| easy / normal / hard | Leicht / Normal / Schwer | — |

#### Scenario: German text uses the glossary words
- **WHEN** the check scans every German value for the glossary's avoided words
- **THEN** none is found

#### Scenario: German text addresses the player with du
- **WHEN** the check scans every German value for formal address ("Sie können", "Sie haben", "Ihnen", "wählen Sie", "bauen Sie")
- **THEN** none is found
